resource "helm_release" "hyperspace" {
  count           = var.create_eks ? 1 : 0
  name            = "hyperspace"
  chart           = "${path.module}/hyperspace-chart"
  wait            = true
  force_update    = true
  cleanup_on_fail = true
  
  values = [
  yamlencode({
    global = {
      environment   = var.environment
      ecr_repository = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    }
    "data-node" = {
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = "arn:aws:iam::${var.aws_account_id}:role/${var.project}-${var.environment}-EC2TagsPolicy"
        }
      }
    }
    "search-master" = {
      ingress = {
        hosts = [
          {
            host = "search-master.${var.environment}.${var.domain_name}"
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
              }
            ]
          }
        ]
      }
    }
    etcd = {
      fullnameOverride = "etcd-${var.environment}"
    }
  })
]
  depends_on = [helm_release.secrets_manager, time_sleep.wait_for_crd]
}