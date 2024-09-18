module "eks_blueprints_addons" {
  source            = "aws-ia/eks-blueprints-addons/aws"
  version           = "1.16.3"
  count             = local.create_eks ? 1 : 0
  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn
  enable_aws_load_balancer_controller = local.create_eks
  aws_load_balancer_controller        = { values = [local.alb_values], wait = true }
}

# Remove non encrypted default storage class
resource "kubernetes_annotations" "default_storageclass" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = "true"

  metadata {
    name = data.kubernetes_storage_class.name.metadata[0].name
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
}

resource "kubernetes_storage_class" "ebs_sc_gp3" {
  metadata {
    name = "ebs-sc-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
#   reclaim_policy      = var.storage_reclaim_policy
  parameters = {
    "csi.storage.k8s.io/fstype" = "ext4"
    encrypted                   = "true"
    type                        = "gp3"
    tagSpecification_1          = "Name={{ .PVCNamespace }}/{{ .PVCName }}"
    tagSpecification_2          = "Namespace={{ .PVCNamespace }}"
  }
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  depends_on             = [kubernetes_annotations.default_storageclass]
}