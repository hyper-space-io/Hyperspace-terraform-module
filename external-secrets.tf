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
  depends_on = [time_sleep.wait_for_cluster_ready]
}

# Wait for CRD creation to be ready
resource "time_sleep" "wait_for_crd" {
  depends_on = [helm_release.secrets_manager]
  create_duration = "30s"
}

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "cluster-secret-store"
    }
    spec = {
      provider = {
        aws = {
          region  = var.aws_region
          service = "SecretsManager"
        }
      }
    }
  }
  depends_on = [helm_release.secrets_manager, time_sleep.wait_for_crd]
}

# resource "kubectl_manifest" "cluster_secret_store" {
#   yaml_body  = <<-EOF
#     apiVersion: external-secrets.io/v1beta1
#     kind: ClusterSecretStore
#     metadata:
#       name: cluster-secret-store
#     spec:
#       provider:
#         aws:
#           region: ${var.aws_region}
#           service: SecretsManager
#   EOF
#   depends_on = [helm_release.secrets_manager, time_sleep.wait_for_crd]
# }