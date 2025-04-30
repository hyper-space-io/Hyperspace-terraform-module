# resource "helm_release" "ecr_token" {
#   count           = local.argocd_enabled ? 1 : 0
#   name            = "ecr-credentials-sync"
#   chart           = "${path.module}/charts/ecr-credentials-sync"
#   namespace       = "argocd"
#   wait            = true
#   force_update    = true
#   cleanup_on_fail = true
#   depends_on      = [module.eks]

#   values = [<<EOT
#     account_id   = "${var.hyperspace_account_id}"
#     ECR_REGISTRY = "${var.hyperspace_account_id}.dkr.ecr.${local.hyperspace_ecr_registry_region}.amazonaws.com"
#     region       = "${local.hyperspace_ecr_registry_region}"
#   EOT
#   ]
# }