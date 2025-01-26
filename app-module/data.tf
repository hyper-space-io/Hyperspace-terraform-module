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
  depends_on = [module.eks]
}

data "kubernetes_ingress_v1" "external_ingress" {
  metadata {
    name      = "external-ingress"
    namespace = "ingress"
  }
  depends_on = [time_sleep.wait_for_external_ingress, module.eks, kubernetes_ingress_v1.nginx_ingress]
}

data "kubernetes_ingress_v1" "internal_ingress" {
  metadata {
    name      = "internal-ingress"
    namespace = "ingress"
  }
  depends_on = [time_sleep.wait_for_internal_ingress, module.eks, kubernetes_ingress_v1.nginx_ingress]
}

data "aws_eks_cluster_auth" "eks" {
  name       = local.cluster_name
  depends_on = [module.eks]
}

data "aws_lb" "nlb" {
  tags = {
    "service.k8s.aws/stack" = "argocd/argocd-server"
    "elbv2.k8s.aws/cluster" = module.eks.cluster_name
  }
  depends_on = [helm_release.argocd]
}