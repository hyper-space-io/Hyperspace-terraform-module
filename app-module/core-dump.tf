locals {
  dump_release_name = "core-dump"
}
resource "helm_release" "core_dump" {
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
  s3BucketName: "${local.s3_buckets["core-dump-logs"].s3_bucket_arn}"
  s3Region: "${local.aws_region}"
serviceAccount:
  name: "${local.dump_release_name}"
  annotations:
    eks.amazonaws.com/role-arn: "${local.iam_roles["${local.dump_release_name}"].iam_role_arn}"
tolerations:
- key: "fpga"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
EOT
  ]
}