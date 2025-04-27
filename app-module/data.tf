#######################
#### Terraform Cloud ##
#######################

data "terraform_remote_state" "infra" {
  backend = "remote"

  config = {
    organization = var.tfe_organization
    workspaces = {
      name = var.infra_workspace_name
    }
  }
}

#######################
######## EKS ##########
#######################

data "kubernetes_storage_class" "name" {
  metadata { name = "gp2" }
  depends_on = [module.eks]
}

data "kubernetes_ingress_v1" "internal_ingress" {
  metadata {
    name      = "internal-ingress"
    namespace = "ingress"
  }
  depends_on = [time_sleep.wait_for_internal_ingress, module.eks, kubernetes_ingress_v1.nginx_ingress]
}

data "kubernetes_ingress_v1" "external_ingress" {
  metadata {
    name      = "external-ingress"
    namespace = "ingress"
  }
  depends_on = [time_sleep.wait_for_external_ingress, module.eks, kubernetes_ingress_v1.nginx_ingress]
}

data "aws_eks_cluster_auth" "eks" {
  name       = local.cluster_name
  depends_on = [module.eks]
}

data "aws_ami" "fpga" {
  owners     = ["${var.hyperspace_account_id}"]
  name_regex = "eks-1\\.31-fpga-prod"
}

#######################
### Load Balancer #####
#######################

resource "time_sleep" "wait_for_argocd_privatelink_nlb" {
  count           = var.create_eks && var.enable_argocd ? 1 : 0
  create_duration = "180s"
  depends_on      = [helm_release.argocd]
}

data "aws_lb" "argocd_privatelink_nlb" {
  count = var.create_eks && var.enable_argocd ? 1 : 0
  tags = {
    "elbv2.k8s.aws/cluster"    = module.eks.cluster_name
    "service.k8s.aws/resource" = "LoadBalancer"
    "service.k8s.aws/stack"    = "argocd/argocd-server"
  }

  depends_on = [time_sleep.wait_for_argocd_privatelink_nlb]
}

#######################
###### ArgoCD #########
#######################

data "aws_secretsmanager_secret_version" "argocd_github_app" {
  count     = var.create_eks && var.enable_argocd && try(local.argocd_vcs_configuration.github.enabled, false) ? 1 : 0
  secret_id = try(local.argocd_vcs_configuration.github.app_secret.name, "argocd/githubapp")
}

data "aws_secretsmanager_secret_version" "argocd_private_key" {
  count     = var.create_eks && var.enable_argocd && try(local.argocd_vcs_configuration.github.enabled, false) ? 1 : 0
  secret_id = try(local.argocd_vcs_configuration.github.private_key_secret.name, "argocd/githubapp-private-key")
}

data "aws_secretsmanager_secret_version" "argocd_gitlab_app" {
  count     = var.create_eks && var.enable_argocd && try(local.argocd_vcs_configuration.gitlab.enabled, false) ? 1 : 0
  secret_id = try(local.argocd_vcs_configuration.gitlab.app_secret.name, "argocd/gitlabapp")
}