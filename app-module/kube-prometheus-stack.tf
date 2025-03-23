locals {
  prometheus_release_name = "kube-prometheus-stack"
}

resource "helm_release" "kube_prometheus_stack" {
  count            = var.create_eks ? 1 : 0
  name             = local.prometheus_release_name
  chart            = local.prometheus_release_name
  create_namespace = true
  cleanup_on_fail  = true
  version          = "68.3.0"
  namespace        = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  values = [<<EOF
global:
  imagePullSecrets:
    - name: "regcred-secret"

grafana:
  ingress:
    enabled: true
    ingressClassName: "${local.internal_ingress_class_name}"
    annotations:
      cert-manager.io/cluster-issuer: "prod-certmanager"
      acme.cert-manager.io/http01-edit-in-place: "true"
      nginx.ingress.kubernetes.io/auth-type: basic
      nginx.ingress.kubernetes.io/auth-secret: none
    hosts:
      - "grafana.${local.internal_domain_name}"
    tls:
      - secretName: "monitoring-tls"
        hosts:
          - "grafana.${local.internal_domain_name}"
  persistence:
    enabled: true
    size: 10Gi

additionalDataSources:
  - name: "loki"
    type: "loki"
    access: "proxy"
    url: "http://loki.monitoring.svc.cluster.local:3100"
    version: 1
    isDefault: false

prometheus:
  prometheusSpec:
    externalLabels:
      environment: "${var.environment}-tfc"
      cluster: "${var.environment}-tfc"
    additionalScrapeConfigs:
      - job_name: "otel_collector"
        scrape_interval: "10s"
        static_configs:
          - targets:
            - "opentelemetry-collector.opentelemetry:9100"
            - "opentelemetry-collector.opentelemetry:8888"
    remoteWrite:
      - url: "https://prometheus.internal.devops-dev.hyper-space.xyz/api/v1/write"
        writeRelabelConfigs:
          - action: "labeldrop"
            regex: "(endpoint|service|prometheus|prometheus_replica)"
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 100Gi
    retention: 365d

alertmanager:
  enabled: true

kubeEtcd:
  enabled: false

kubeControllerManager:
  enabled: false

kubeScheduler:
  enabled: false
EOF
  ]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = random_password.grafana_admin_password.result
  }
  depends_on = [module.eks, time_sleep.wait_for_internal_ingress]
}

resource "helm_release" "prometheus_adapter" {
  name       = "prometheus-adapter"
  version    = "~> 4.11.0"
  namespace  = "monitoring"
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

resource "random_password" "grafana_admin_password" {
  length           = 30
  special          = true
  override_special = "_%@"
}

resource "aws_vpc_endpoint" "prometheus" {
  vpc_id              = local.vpc_module.vpc_id
  service_name        = var.prometheus_endpoint_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_module.private_subnets
  security_group_ids  = [aws_security_group.prometheus_endpoint_service.id]
  private_dns_enabled = true
  ip_address_type     = "ipv4"
  service_region      = var.prometheus_endpoint_service_region

  tags = merge(local.tags, {
    Name = "Prometheus Endpoint - ${var.project}-${var.environment}"
  })
}

resource "aws_security_group" "prometheus_endpoint_service" {
  name        = "prometheus-endpoint-service"
  description = "Security group for prometheus endpoint service"
  vpc_id      = local.vpc_module.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = distinct(concat([local.vpc_module.vpc_cidr_block], jsondecode(var.prometheus_endpoint_additional_cidr_blocks)))
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}