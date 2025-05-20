resource "helm_release" "hyperspace" {
  count           = var.create_eks ? 1 : 0
  name            = "hyperspace"
  chart           = "${path.module}/hyperspace-chart"
  wait            = true
  force_update    = true
  cleanup_on_fail = true
  
  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "global.environment"
    value = var.environment
  }

  set {
    name  = "global.ecr_repository"
    value = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  }

  set {
    name  = "data-node.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = "arn:aws:iam::${var.aws_account_id}:role/${var.project}-${var.environment}-EC2TagsPolicy"
  }

  set {
    name  = "search-master.ingress.hosts[0].host"
    value = "search-master.${var.environment}.${var.domain_name}"
  }

  set {
    name  = "etcd.fullnameOverride"
    value = "etcd-${var.environment}"
  }

  depends_on = [helm_release.secrets_manager, time_sleep.wait_for_crd]
}