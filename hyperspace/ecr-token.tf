resource "helm_release" "ecr_token" {
  count           = local.create_eks ? 1 : 0
  name            = "ecr-credentials-sync"
  chart           = "${path.module}/ecr-credentials-sync"
  namespace       = "argocd"
  wait            = true
  force_update    = true
  cleanup_on_fail = true
  depends_on      = [module.eks, module.vpc, aws_route.peering_routes, helm_release.argocd]
}