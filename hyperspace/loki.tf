resource "helm_release" "loki" {
  count            = local.create_eks ? 1 : 0
  name             = "loki"
  namespace        = "monitoring"
  create_namespace = true
  cleanup_on_fail  = true
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  version          = "~> 2.10.2"
  wait             = true
  values = [<<EOF
loki:
  serviceAccount:
    name: loki
    create: true
    annotations:
      eks.amazonaws.com/role-arn: "${module.iam_iam-assumable-role-with-oidc["loki"].iam_role_arn}"

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
            prefix: "${local.cluster_name}-loki-index-"
            period: "8904h"

    storage_config:
      aws:
        s3: "s3://${var.aws_region}/${module.s3_buckets["loki"].s3_bucket_id}"
        s3forcepathstyle: true
        bucketnames: "${module.s3_buckets["loki"].s3_bucket_id}"
        region: "${var.aws_region}"
        insecure: false
        sse_encryption: true

        dynamodb:
          dynamodb_url: "dynamodb://${var.aws_region}"
    
    table_manager:
      retention_deletes_enabled: true
      retention_period: "8904h"
      index_tables_provisioning:
        enable_ondemand_throughput_mode: true
        enable_inactive_throughput_on_demand_mode: true
    
promtail:
  tolerations:
  - key: "fpga"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
EOF
  ]
  depends_on = [module.eks, module.iam_iam-assumable-role-with-oidc, module.vpc, aws_route.peering_routes]
}
