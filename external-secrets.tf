locals {
  external_secrets_release_name = "external-secrets"
}

resource "helm_release" "secrets_manager" {
  count            = var.create_eks ? 1 : 0
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

resource "kubectl_manifest" "cluster_secret_store" {
  yaml_body  = <<-EOF
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: cluster-secret-store
    spec:
      provider:
        aws:
          region: ${var.aws_region}
          service: SecretsManager
  EOF
  depends_on = [helm_release.secrets_manager, module.eks]
}