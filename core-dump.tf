locals {
  dump_release_name = "core-dump"
}
resource "helm_release" "core_dump" {
  count            = var.create_eks && var.enable_core_dump ? 1 : 0
  name             = local.dump_release_name
  chart            = "${local.dump_release_name}-handler"
  version          = "~> 9.0.0"
  repository       = "https://ibm.github.io/core-dump-handler"
  namespace        = local.dump_release_name
  create_namespace = true
  cleanup_on_fail  = true
  values = [<<EOT
daemonset:
  includeCrioExe: true
  vendor: rhel7
  s3BucketName: "${local.s3_bucket_names["core-dump-logs"]}"
  s3Region: "${var.aws_region}"
serviceAccount:
  name: "${local.dump_release_name}"
  annotations:
    eks.amazonaws.com/role-arn: "${module.iam_iam-assumable-role-with-oidc[local.dump_release_name].iam_role_arn}"
tolerations:
- key: "fpga"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
- key: "system-tools"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
EOT
  ]
  depends_on = [module.eks]
}
