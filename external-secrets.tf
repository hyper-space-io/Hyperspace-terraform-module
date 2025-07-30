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
    eks.amazonaws.com/role-arn: "${module.iam_iam-assumable-role-with-oidc[local.external_secrets_release_name].iam_role_arn}"
installCRDs: true
tolerations:
- key: "system-tools"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
nodeSelector:
  "node-type": "karpenter-system-tools-node"
EOF
  ]
  depends_on = [time_sleep.wait_for_cluster_ready]
}

# Wait for CRD creation to be ready
resource "time_sleep" "wait_for_crd" {
  count           = var.create_eks ? 1 : 0
  depends_on      = [helm_release.secrets_manager]
  create_duration = "30s"
}

# Install the secret manager manifests with helm chart as kubectl_manifest and kubernetes_manifest resources don't work well with CRDS
resource "helm_release" "secret_manager_manifests" {
  count           = var.create_eks ? 1 : 0
  name            = "secret-manager-manifests"
  namespace       = local.external_secrets_release_name
  chart           = "${path.module}/secrets-manager-manifests"
  wait            = true
  force_update    = true
  cleanup_on_fail = true
  set {
    name  = "awsRegion"
    value = var.aws_region
  }
  depends_on = [helm_release.secrets_manager, time_sleep.wait_for_crd]
}