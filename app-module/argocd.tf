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
  argo_release_name = "argo-cd"
}

resource "helm_release" "argocd" {
  count            = var.enable_argocd ? 1 : 0
  chart            = local.argo_release_name
  version          = "~> 7.7.3"
  name             = local.argo_release_name
  namespace        = local.argo_release_name
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  values           = [local.argocd_values]
}