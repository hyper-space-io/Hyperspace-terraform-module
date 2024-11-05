resource "helm_release" "loki" {
  name       = "loki"
  namespace  = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = "~> 2.10.2"
  wait       = true
  values = [<<EOF
loki:
  serviceAccount:
    name: loki
    create: true
    annotations:
      eks.amazonaws.com/role-arn: "${local.iam_roles["loki"].iam_role_arn}"

  extraArgs:
    target: all,table-manager

  config:
    schema_config:
      configs:
        - from: "2024-01-01"
          store: "aws"
          object_store: "s3"
          schema: "v11"
          index:
            prefix: "${local.eks_module.cluster_name}-loki-index-"
            period: "8904h"

    storage_config:
      aws:
        s3: "s3://${local.aws_region}/${local.s3_buckets["loki"].s3_bucket_id}"
        s3forcepathstyle: true
        bucketnames: "${local.s3_buckets["loki"].s3_bucket_id}"
        region: "${local.aws_region}"
        insecure: false
        sse_encryption: true

        dynamodb:
          dynamodb_url: "dynamodb://${local.aws_region}"
    
    table_manager:
      retention_deletes_enabled: true
      retention_period: "8904h"
    
promtail:
  tolerations:
  - key: "fpga"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
EOF
  ]
}