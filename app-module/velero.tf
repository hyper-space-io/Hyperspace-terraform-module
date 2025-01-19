resource "helm_release" "velero" {
  name             = "velero"
  chart            = "velero"
  version          = "~>8.0.0"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  namespace        = "velero"
  create_namespace = true
  values = [<<EOF
  initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.11.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins
  configuration:
    backupStorageLocation:
      - name: "s3"
        default: true
        provider: "aws"
        bucket: "${local.s3_buckets["velero"].s3_bucket_id}"
        accessMode: "ReadWrite"
        config: {
          region: "${local.aws_region}"
        }
    volumeSnapshotLocation:
      - name: "aws"
        provider: "aws"
        config: {
          region: "${local.aws_region}"
        }
  podAnnotations: {
   eks.amazonaws.com/role-arn: "${local.iam_roles["velero"].iam_role_arn}"
  }
  defaultBackupStorageLocation: "s3"
  credentials:
    useSecret: false
  serviceAccount:
    server:
      annotations:
        eks.amazonaws.com/role-arn: "${local.iam_roles["velero"].iam_role_arn}"
  EOF
  ]
  depends_on = [module.eks]
}