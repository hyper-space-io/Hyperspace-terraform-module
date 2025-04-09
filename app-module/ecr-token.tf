resource "helm_release" "ecr_token" {
  count           = 0
  name            = "ecr-credentials-sync"
  chart           = "${path.module}/ecr-credentials-sync"
  namespace       = "argocd"
  wait            = true
  force_update    = true
  cleanup_on_fail = true
  depends_on      = [module.eks]

  values = [<<EOT
    account_id   = "${var.hyperspace_account_id}"
    ECR_REGISTRY = "${var.hyperspace_account_id}.dkr.ecr.eu-west-1.amazonaws.com"
  EOT
  ]
}