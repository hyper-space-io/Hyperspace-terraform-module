locals {
  prometheus_release_name = "kube-prometheus-stack"
}
resource "helm_release" "kube_prometheus_stack" {
  count            = var.create_eks ? 1 : 0
  name             = local.prometheus_release_name
  chart            = local.prometheus_release_name
  create_namespace = true
  cleanup_on_fail  = true
  version          = "~> 65.5.0"
  namespace        = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  values = [<<EOF
global:

  imagePullSecrets:
    - name: "regcred-secret"

commonLabels:

  environment: "${var.environment}"

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
    additionalScrapeConfigs:
      - job_name: "otel_collector"
        scrape_interval: "10s"
        static_configs:
          - targets:
            - "opentelemetry-collector.opentelemetry:9100"
            - "opentelemetry-collector.opentelemetry:8888"
    remoteWrite:
      - url: "https://prometheus.internal.devops-dev.hyper-space.xyz/api/v1/write"
        remoteTimeout: 30s
        queueConfig:
          capacity: 10000
          maxShards: 200
          maxSamplesPerSend: 1000
          batchSendDeadline: 30s
          minShards: 1
          maxRetries: 5
          minBackoff: 1s
          maxBackoff: 300s
        writeRelabelConfigs:
          # Keep only metrics with specific names
          - sourceLabels: [__name__]
            regex: '(container_.*|kube_.*|node_.*)'
            action: keep
          # Keep only specific labels
          - regex: '(container|pod|namespace|node|service|job|instance|environment)'
            action: labelkeep
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