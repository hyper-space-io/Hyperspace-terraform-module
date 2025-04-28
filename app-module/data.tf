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

#### ArgoCD Privatelink ####
resource "time_sleep" "wait_for_argocd_privatelink_nlb" {
  count           = local.argocd_enabled ? 1 : 0
  create_duration = "180s"
  depends_on      = [helm_release.argocd]
}

data "aws_lb" "argocd_privatelink_nlb" {
  count = local.argocd_enabled ? 1 : 0
  tags = {
    "elbv2.k8s.aws/cluster"    = module.eks.cluster_name
    "service.k8s.aws/resource" = "LoadBalancer"
    "service.k8s.aws/stack"    = "argocd/argocd-server"
  }

  depends_on = [time_sleep.wait_for_argocd_privatelink_nlb]
}

#### Grafana Privatelink ####
resource "time_sleep" "wait_for_grafana_privatelink_nlb" {
  count           = local.grafana_privatelink_enabled ? 1 : 0
  create_duration = "180s"
  depends_on      = [helm_release.grafana]
}

data "aws_lb" "grafana_privatelink_nlb" {
  count = local.grafana_privatelink_enabled ? 1 : 0
  tags = {
    "elbv2.k8s.aws/cluster"    = module.eks.cluster_name
    "service.k8s.aws/resource" = "LoadBalancer"
    "service.k8s.aws/stack"    = "grafana/grafana"
  }

  depends_on = [time_sleep.wait_for_grafana_privatelink_nlb]
}

#######################
###### ArgoCD #########
#######################

data "aws_secretsmanager_secret_version" "argocd_github_app" {
  count     = local.github_vcs_enabled ? 1 : 0
  secret_id = local.argocd_config.vcs.github.app_secret_name
}

data "aws_secretsmanager_secret_version" "argocd_private_key" {
  count     = local.github_vcs_enabled ? 1 : 0
  secret_id = local.argocd_config.vcs.github.private_key_secret
}

data "aws_secretsmanager_secret_version" "argocd_gitlab_app" {
  count     = local.gitlab_vcs_enabled ? 1 : 0
  secret_id = local.argocd_config.vcs.gitlab.app_secret_name
}