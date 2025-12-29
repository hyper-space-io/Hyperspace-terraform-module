resource "helm_release" "kubernetes-event-exporter" {
  name       = "kubernetes-event-exporter"
  namespace  = "monitoring"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "kubernetes-event-exporter"
  version    = "~>3.5.0"
  values = [<<EOF
nodeSelector:
  "node-type": "karpenter-system-tools-node"
tolerations:
- key: "system-tools"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
EOF
]
}