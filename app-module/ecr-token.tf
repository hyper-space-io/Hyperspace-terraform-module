resource "helm_release" "ecr_token_sync" {
  name            = "ecr-credentials-sync"
  chart           = "${path.module}/ecr-credentials-sync"
  wait            = true
  force_update    = true
  cleanup_on_fail = true
}