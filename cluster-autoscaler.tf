locals {
  autoscaler_release_name = "cluster-autoscaler"
}
resource "helm_release" "cluster_autoscaler" {
  count            = var.create_eks ? 1 : 0
  chart            = local.autoscaler_release_name
  namespace        = local.autoscaler_release_name
  name             = local.autoscaler_release_name
  create_namespace = true
  version          = "~> 9.43.2"
  repository       = "https://kubernetes.github.io/autoscaler"
  values = [<<EOF
extraArgs:
  scale-down-delay-after-add: 30s
  scale-down-unneeded-time: 10m
awsRegion: "${var.aws_region}"
autoDiscovery:
  clusterName: "${local.cluster_name}"
rbac:
  create: true
  serviceAccount:
    create: true
    name: cluster-autoscaler
    annotations:
      eks.amazonaws.com/role-arn: "${module.iam_iam-assumable-role-with-oidc[local.autoscaler_release_name].iam_role_arn}"
EOF
  ]
  depends_on = [module.eks]
}