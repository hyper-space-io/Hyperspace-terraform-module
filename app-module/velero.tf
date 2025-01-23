resource "helm_release" "velero" {
  count            = var.create_eks ? 1 : 0
  name             = "velero"
  chart            = "velero"
  version          = "~>8.0.0"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  namespace        = "velero"
  create_namespace = true
  cleanup_on_fail  = true
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
        bucket: "${local.s3_bucket_names["velero"]}"
        accessMode: "ReadWrite"
        config: {
          region: "${var.aws_region}"
        }
    volumeSnapshotLocation:
      - name: "aws"
        provider: "aws"
        config: {
          region: "${var.aws_region}"
        }
  podAnnotations: {
   eks.amazonaws.com/role-arn: "${module.iam_iam-assumable-role-with-oidc["velero"].iam_role_arn}"
  }
  defaultBackupStorageLocation: "s3"
  credentials:
    useSecret: false
  serviceAccount:
    server:
      annotations:
        eks.amazonaws.com/role-arn: "${module.iam_iam-assumable-role-with-oidc["velero"].iam_role_arn}"
  EOF
  ]
  depends_on = [module.eks, module.iam_iam-assumable-role-with-oidc, provider.helm]
}