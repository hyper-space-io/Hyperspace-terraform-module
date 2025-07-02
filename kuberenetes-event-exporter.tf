resource "helm_release" "kubernetes-event-exporter" {
  name       = "kubernetes-event-exporter"
  namespace  = "monitoring"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kubernetes-event-exporter"
  version    = "2.7.2"
}