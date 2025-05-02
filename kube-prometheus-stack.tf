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
  vpc_id              = module.vpc.vpc_id
  service_name        = local.prometheus_endpoint_config.endpoint_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
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
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = distinct(concat([module.vpc.vpc_cidr_block], local.prometheus_endpoint_config.additional_cidr_blocks))
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

resource "null_resource" "grafana_privatelink_nlb_active" {
  count = local.grafana_privatelink_enabled ? 1 : 0
  provisioner "local-exec" {
    command = <<EOF
      NLB_ARN="${data.aws_lb.grafana_privatelink_nlb[0].arn}"
      if [ -z "$NLB_ARN" ]; then
        echo "Terraform data source did not return an ARN. Attempting to find NLB via AWS CLI tags..."
        NLB_ARN=$(aws resourcegroupstaggingapi get-resources \
          --region ${var.aws_region} \
          --resource-type-filters elasticloadbalancing:loadbalancer \
          --tag-filters Key=elbv2.k8s.aws/cluster,Values=${local.cluster_name} \
                        Key=service.k8s.aws/resource,Values=LoadBalancer \
                        Key=service.k8s.aws/stack,Values=monitoring/grafana \
          --query 'ResourceTagMappingList[0].ResourceARN' \
          --output text)
        if [ -z "$NLB_ARN" ]; then
          echo "Could not find Grafana NLB via AWS CLI tag lookup either. Exiting."
          exit 1
        else
          echo "Found NLB ARN via AWS CLI tag lookup: $NLB_ARN"
        fi
      fi
      TIMEOUT=300
      START_TIME=$(date +%s)
      while true; do
        STATE=$(aws elbv2 describe-load-balancers --region ${var.aws_region} --load-balancer-arns $NLB_ARN --query 'LoadBalancers[0].State.Code' --output text 2>/dev/null)
        if [ "$STATE" = "active" ]; then
          echo "Grafana NLB is now active"
          break
        fi
        if [ $(( $(date +%s) - $START_TIME )) -ge $TIMEOUT ]; then
          echo "Timed out waiting for Grafana NLB to become active"
          exit 1
        fi
        echo "Waiting for Grafana NLB to become active... Current state: $STATE"
        sleep 10
      done
    EOF
  }
  triggers = {
    nlb_arn = data.aws_lb.grafana_privatelink_nlb[0].arn
  }
}

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