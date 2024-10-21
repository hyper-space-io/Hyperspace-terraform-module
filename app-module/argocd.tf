locals {
  argocd_values = templatefile("${path.module}/argocd_values.tftpl", {
    dex_enabled              = length(var.dex_connectors) > 0
    domain                   = local.internal_domain_name
    dex_connectors           = var.dex_connectors
    rbac_policy_default      = var.argocd_rbac_policy_default
    rbac_policy_rules        = var.argocd_rbac_policy_rules
    enable_high_availability = var.enable_ha_argocd
    ingress_enabled          = local.eks_exists
    ingress_class            = "nginx-internal"
  })
}

resource "helm_release" "argocd" {
  count            = var.enable_argocd ? 1 : 0
  chart            = "argo-cd"
  version          = "~> 7.2.0"
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  values           = [local.argocd_values]
}

resource "helm_release" "system_tools" {
  name            = "system-tools"
  chart           = "${path.module}/system-tools"
  version         = "1.0.1"
  wait            = true
  force_update    = true
  cleanup_on_fail = true
  values = [<<EOF
awsRegion: "${local.aws_region}"
clusterName: "${local.eks_module.cluster_name}"
clusterAutoscaler:
    roleArn: "${local.iam_roles["cluster-autoscaler"].iam_role_arn}"
updateTimestamp: "${timestamp()}"
EOF
  ]
  depends_on = [helm_release.argocd]
}