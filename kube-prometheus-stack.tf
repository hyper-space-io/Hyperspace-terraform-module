locals {
  prometheus_release_name = "kube-prometheus-stack"
  monitoring_namespace    = "monitoring"

  prometheus_values = {
    global = {
      imagePullSecrets = [
        {
          name = "regcred-secret"
        }
      ]
    }

    grafana = {
      enabled = false
    }

    additionalDataSources = [
      {
        name      = "loki"
        type      = "loki"
        access    = "proxy"
        url       = "http://loki.monitoring.svc.cluster.local:3100"
        version   = 1
        isDefault = false
      }
    ]

    prometheus = {
      prometheusSpec = merge({
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              accessModes = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = "50Gi"
                }
              }
            }
          }
        }
        additionalScrapeConfigs = [
          {
            job_name        = "otel_collector"
            scrape_interval = "10s"
            static_configs = [
              {
                targets = [
                  "opentelemetry-collector.opentelemetry:9100",
                  "opentelemetry-collector.opentelemetry:8888"
                ]
              }
            ]
          }
        ]
        retention = "365d"
        }, local.prometheus_endpoint_enabled ? {
        externalLabels = {
          cluster = local.cluster_name
        }
        remoteWrite = [
          {
            url = local.prometheus_remote_write_endpoint
          }
        ]
        } : {
        externalLabels = {}
        remoteWrite    = []
      })
    }

    alertmanager = {
      enabled = true
    }

    kubeEtcd = {
      enabled = false
    }

    kubeControllerManager = {
      enabled = false
    }

    kubeScheduler = {
      enabled = false
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  count            = var.create_eks ? 1 : 0
  name             = local.prometheus_release_name
  chart            = local.prometheus_release_name
  create_namespace = true
  cleanup_on_fail  = true
  version          = "68.3.0"
  namespace        = local.monitoring_namespace
  repository       = "https://prometheus-community.github.io/helm-charts"
  values           = [yamlencode(local.prometheus_values)]
  depends_on       = [module.eks]
}

resource "random_password" "grafana_admin_password" {
  length           = 30
  special          = true
  override_special = "_%@"
}

resource "helm_release" "grafana" {
  count            = var.create_eks ? 1 : 0
  name             = "grafana"
  version          = "~> 8.8.0"
  namespace        = local.monitoring_namespace
  chart            = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  create_namespace = true
  cleanup_on_fail  = true
  values = [
    yamlencode({
      adminPassword = random_password.grafana_admin_password.result
      service = {
        type = local.grafana_privatelink_enabled ? "LoadBalancer" : "ClusterIP"
        annotations = local.grafana_privatelink_enabled ? {
          "service.beta.kubernetes.io/aws-load-balancer-internal"               = "true"
          "service.beta.kubernetes.io/aws-load-balancer-type"                   = "nlb-ip"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"                 = "internal"
          "service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy" = "ELBSecurityPolicy-TLS13-1-2-2021-06"
        } : {}
      }
      ingress = {
        enabled          = true
        ingressClassName = local.internal_ingress_class_name
        hosts = [
          "grafana.${local.internal_domain_name}"
        ]
      }
      persistence = {
        enabled = true
        size    = "10Gi"
      }
    })
  ]

  set_sensitive {
    name  = "adminPassword"
    value = random_password.grafana_admin_password.result
  }

  depends_on = [module.eks, time_sleep.wait_for_internal_ingress, module.eks_blueprints_addons]
}

resource "helm_release" "prometheus_adapter" {
  name       = "prometheus-adapter"
  version    = "~> 4.11.0"
  namespace  = local.monitoring_namespace
  chart      = "prometheus-adapter"
  repository = "https://prometheus-community.github.io/helm-charts"
  values = [<<EOF
resources:
  requests:
    cpu: "10m"
    memory: "32Mi"
prometheus:
  url: http://"kube-prometheus-stack-prometheus.monitoring.svc"
EOF
  ]
  depends_on = [helm_release.kube_prometheus_stack, module.eks, module.eks_blueprints_addons]
}


##################################
##### Prometheus Endpoint ########
##################################

resource "aws_vpc_endpoint" "prometheus" {
  count               = local.prometheus_endpoint_enabled ? 1 : 0
  vpc_id              = local.vpc_id
  service_name        = local.prometheus_endpoint_config.endpoint_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnets_ids
  security_group_ids  = [aws_security_group.prometheus_endpoint[0].id]
  private_dns_enabled = true
  ip_address_type     = "ipv4"
  service_region      = local.prometheus_endpoint_config.endpoint_service_region

  tags = merge(local.tags, {
    Name = "Prometheus Endpoint - ${var.project}-${var.environment}"
  })
}

resource "aws_security_group" "prometheus_endpoint" {
  count       = local.prometheus_endpoint_enabled ? 1 : 0
  name        = "prometheus-endpoint"
  description = "Security group for prometheus endpoint"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = distinct(concat([local.vpc_cidr_block], local.prometheus_endpoint_config.additional_cidr_blocks))
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


##################################
####### Grafana Privatelink ######
##################################

resource "aws_vpc_endpoint_service" "grafana" {
  count                      = local.grafana_privatelink_enabled ? 1 : 0
  acceptance_required        = false
  network_load_balancer_arns = [data.aws_lb.grafana_privatelink_nlb[0].arn]
  allowed_principals         = local.grafana_privatelink_allowed_principals
  supported_regions          = local.grafana_privatelink_supported_regions
  private_dns_name           = "grafana.${var.project}.${local.internal_domain_name}"

  tags = merge(local.tags, {
    Name = "Grafana Endpoint Service - ${var.project}-${var.environment}"
  })

  depends_on = [data.aws_lb.grafana_privatelink_nlb[0]]
}

resource "aws_route53_record" "grafana_privatelink_verification" {
  count   = local.grafana_privatelink_enabled && local.validation_zone_id != "" ? 1 : 0
  zone_id = local.validation_zone_id
  name    = aws_vpc_endpoint_service.grafana[0].private_dns_name_configuration[0].name
  type    = aws_vpc_endpoint_service.grafana[0].private_dns_name_configuration[0].type
  ttl     = 300
  records = [aws_vpc_endpoint_service.grafana[0].private_dns_name_configuration[0].value]

  depends_on = [aws_vpc_endpoint_service.grafana]
}