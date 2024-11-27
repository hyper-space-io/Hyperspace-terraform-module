locals {
  external_secrets_release_name = "external-secrets"
}
resource "helm_release" "secrets_manager" {
  namespace        = "external-secrets"
  chart            = "external-secrets"
  name             = "external-secrets"
  create_namespace = true
  wait             = true
  version          = "~> 0.10.5"
  repository       = "https://charts.external-secrets.io/"
  values           =[<<EOF
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "${local.iam_roles["external-secrets"].iam_role_arn}"
installCRDs: true
EOF
  ]
}

resource "helm_release" "secret_manager_manifests" {
  name            = "secret-manager-manifests"
  chart           = "${path.module}/secrets-manager-manifests"
  wait            = true
  force_update    = true
  cleanup_on_fail = true
  values = [<<EOT
  awsRegion: "${local.aws_region}"
  EOT
  ]
  depends_on      = [ helm_release.secrets_manager ]
}