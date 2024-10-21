# resource "helm_release" "cluster_autoscaler" {
#   count            = var.enable_cluster_autoscaler ? 1 : 0
#   chart            = "cluster-autoscaler"
#   namespace        = "cluster-autoscaler"
#   name             = "cluster-autoscaler"
#   create_namespace = true
#   version          = "9.37.0"
#   repository       = "https://kubernetes.github.io/autoscaler"
#   values = [<<EOF
# extraArgs:
#   scale-down-delay-after-add: 30s
#   scale-down-unneeded-time: 10m
# awsRegion: ${local.aws_region}
# autoDiscovery:
#   clusterName: ${local.eks_module.cluster_name}
# rbac:
#   create: "true"
#   serviceAccount:
#     create: "true"
#     name: "cluster_autoscaler"
#     annotations:
#       eks.amazonaws.com/role-arn: ${local.iam_roles["cluster_autoscaler"].iam_role_arn}
# EOF
#   ]
# }