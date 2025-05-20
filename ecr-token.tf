resource "helm_release" "ecr_token" {
  count           = var.create_eks ? 1 : 0
  name            = "ecr-credentials-sync"
  chart           = "${path.module}/ecr-credentials-sync"
  namespace       = "argocd"
  wait            = true
  force_update    = true
  cleanup_on_fail = true
  depends_on      = [module.eks, time_sleep.wait_for_cluster_ready, helm_release.argocd]

  set {
    name  = "ACCOUNT_ID"
    value = "${var.hyperspace_account_id}"
  }
}