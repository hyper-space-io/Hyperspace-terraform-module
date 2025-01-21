locals {
  external_secrets_release_name = "external-secrets"
}
resource "helm_release" "secrets_manager" {
  count            = 0
  namespace        = local.external_secrets_release_name
  chart            = local.external_secrets_release_name
  name             = local.external_secrets_release_name
  create_namespace = true
  wait             = true
  version          = "~> 0.10.5"
  repository       = "https://charts.external-secrets.io/"
  values = [<<EOF
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "${module.iam_iam-assumable-role-with-oidc["${local.external_secrets_release_name}"].iam_role_arn}"
installCRDs: true
EOF
  ]
  depends_on = [module.eks]
}

resource "helm_release" "secret_manager_manifests" {
  name            = "secret-manager-manifests"
  chart           = "${path.module}/secrets-manager-manifests"
  wait            = true
  force_update    = true
  cleanup_on_fail = true
  values = [<<EOT
  awsRegion: "${var.aws_region}"
  EOT
  ]
  depends_on = [helm_release.secrets_manager, module.eks, module.iam_iam-assumable-role-with-oidc]
}