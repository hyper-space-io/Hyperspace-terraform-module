resource "time_sleep" "wait_for_cluster_ready" {
  count           = var.create_eks ? 1 : 0
  create_duration = "90s"
  depends_on      = [module.eks, time_sleep.wait_for_internal_ingress]
}

resource "helm_release" "opentelemetry-collector" {
  count            = var.create_eks ? 1 : 0
  name             = "opentelemetry-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  version          = "0.96.0"
  chart            = "opentelemetry-collector"
  namespace        = "opentelemetry"
  create_namespace = true
  cleanup_on_fail  = true
  wait             = true
  values = [<<EOT
mode: "deployment"
config:
  exporters:
    prometheus:
      endpoint: 0.0.0.0:9100
      const_labels:
        source: opentelemetry
    debug:
      verbosity: detailed
  service:
    extensions:
      - health_check
    pipelines:
      metrics:
        receivers:
          - otlp
        processors:
          - batch
        exporters:
        - prometheus
        - debug
ports:
  prometheus:
    enabled: true
    containerPort: 9100
    servicePort: 9100
    hostPort: 9100
    protocol: TCP
image:
  repository: "otel/opentelemetry-collector-contrib"
useGOMEMLIMIT: true
EOT
  ]
  depends_on = [time_sleep.wait_for_cluster_ready]
}