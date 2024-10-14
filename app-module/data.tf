data "terraform_remote_state" "infra" {
  backend = "remote"

  config = {
    organization = var.organization
    workspaces = {
      name = var.infra_workspace_name
    }
  }
}

data "kubernetes_storage_class" "name" {
  metadata { name = "gp2" }
}

data "kubernetes_ingress_v1" "ingress" {
  metadata {
    name      = "external-ingress"
    namespace = "ingress"
  }
  depends_on = [time_sleep.wait_for_external_ingress]
}

data "kubernetes_ingress_v1" "internal_ingress" {
  metadata {
    name      = "internal-ingress"
    namespace = "ingress"
  }
  depends_on = [time_sleep.wait_for_internal_ingress]
}

data "aws_eks_cluster_auth" "eks" {
  name = local.eks_module.cluster_name
}