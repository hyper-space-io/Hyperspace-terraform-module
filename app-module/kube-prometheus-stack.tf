# locals {
#   prometheus_release_name = "kube-prometheus-stack"
# }
# resource "helm_release" "kube_prometheus_stack" {
#   name       = local.prometheus_release_name
#   chart      = local.prometheus_release_name
#   version    = "~> 65.5.0"
#   namespace  = "monitoring"
#   repository = "https://prometheus-community.github.io/helm-charts"
#   values = [<<EOF
# global:

#   imagePullSecrets:
#     - name: "regcred-secret"

# commonLabels:

#   environment: "${local.environment}"

# grafana:

#   ingress:
#     enabled: true
#     ingressClassName: "${local.internal_ingress_class_name}"
#     annotations:
#       cert-manager.io/cluster-issuer: "prod-certmanager"
#       acme.cert-manager.io/http01-edit-in-place: "true"
#       nginx.ingress.kubernetes.io/auth-type: basic
#       nginx.ingress.kubernetes.io/auth-secret: none
#     hosts:
#       - "grafana.${local.internal_domain_name}"
#     tls:
#       - secretName: "monitoring-tls"
#         hosts:
#           - "grafana.${local.internal_domain_name}"

#   persistence:
#     enabled: true
#     size: 10Gi

# additionalDataSources:
#   - name: "loki"
#     type: "loki"
#     access: "proxy"
#     url: "http://loki.monitoring.svc.cluster.local:3100"
#     version: 1
#     isDefault: false

# prometheus:
#   prometheusSpec:
#     additionalScrapeConfigs:
#       - job_name: "otel_collector"
#         scrape_interval: "10s"
#         static_configs:
#           - targets:
#             - "opentelemetry-collector.opentelemetry:9100"
#             - "opentelemetry-collector.opentelemetry:8888"
#     storageSpec:
#       volumeClaimTemplate:
#         spec:
#           resources:
#             requests:
#               storage: 100Gi
#     retention: 365d

# alertmanager:
#   enabled: true

# kubeEtcd:
#   enabled: false

# kubeControllerManager:
#   enabled: false

# kubeScheduler:
#   enabled: false    
# EOF
#   ]
#   set_sensitive {
#     name  = "grafana.adminPassword"
#     value = random_password.grafana_admin_password.result
#   }
# }

# resource "helm_release" "prometheus_adapter" {
#   name       = "prometheus-adapter"
#   version    = "~> 4.11.0"
#   namespace  = "monitoring"
#   chart      = "prometheus-adapter"
#   repository = "https://prometheus-community.github.io/helm-charts"
#   values = [<<EOF
# resources:
#   requests:
#     cpu: "10m"
#     memory: "32Mi"
# prometheus:
#   url: http://"kube-prometheus-stack-prometheus.monitoring.svc"
# EOF
#   ]
#   depends_on = [helm_release.kube_prometheus_stack]
# }

# resource "random_password" "grafana_admin_password" {
#   length           = 30
#   special          = true
#   override_special = "_%@"
# }