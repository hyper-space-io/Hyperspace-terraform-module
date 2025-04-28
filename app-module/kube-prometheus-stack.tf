locals {
  prometheus_release_name      = "kube-prometheus-stack"
  prometheus_crds_release_name = "prometheus-operator-crds"
  monitoring_namespace         = "monitoring"

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
  name             = "grafana"
  version          = "~> 8.8.0"
  namespace        = local.monitoring_namespace
  chart            = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  create_namespace = true
  cleanup_on_fail  = true
  values = [<<EOF
adminPassword: "${random_password.grafana_admin_password.result}"
ingress:
  enabled: true
  ingressClassName: "${local.internal_ingress_class_name}"
  annotations:
    # cert-manager.io/cluster-issuer: "prod-certmanager"
    # acme.cert-manager.io/http01-edit-in-place: "true"
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: none
  hosts:
    - "grafana.${local.internal_domain_name}"
  # tls:
  #   - secretName: "monitoring-tls"
  #     hosts:
  #       - "grafana.${local.internal_domain_name}"
persistence:
  enabled: true
  size: 10Gi
EOF
  ]

  set_sensitive {
    name  = "adminPassword"
    value = random_password.grafana_admin_password.result
  }

  depends_on = [module.eks, time_sleep.wait_for_internal_ingress]
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
  depends_on = [helm_release.kube_prometheus_stack, module.eks]
}


##################################
##### Prometheus Endpoint ########
##################################

resource "aws_vpc_endpoint" "prometheus" {
  count               = local.prometheus_endpoint_enabled ? 1 : 0
  vpc_id              = local.vpc_module.vpc_id
  service_name        = local.prometheus_endpoint_config.endpoint_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_module.private_subnets
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
  vpc_id      = local.vpc_module.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = distinct(concat([local.vpc_module.vpc_cidr_block], local.prometheus_endpoint_config.additional_cidr_blocks))
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}