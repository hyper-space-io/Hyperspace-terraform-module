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

# awsRegion: "${local.aws_region}"
# internalDomainName: ${local.internal_domain_name}
# clusterName: "${local.eks_module.cluster_name}"
# coredump:
#   bucketArn: "${local.s3_buckets["core-dump-logs"].s3_bucket_arn}"
#   vendor: "rhel7"
#   roleArn: "${local.iam_roles["core-dump"].iam_role_arn}"
# velero:
#   bucketID: "${local.s3_buckets["velero"].s3_bucket_id}"
#   roleArn: "${local.iam_roles["velero"].iam_role_arn}"
