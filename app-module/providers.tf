provider "kubernetes" {
  host                   = local.eks_module.cluster_endpoint
  cluster_ca_certificate = base64decode(local.eks_module.cluster_certificate_authority_data)
  token                  = data.terraform_remote_state.infra.outputs.eks_token
}

provider "helm" {
  kubernetes {
    host                   = local.eks_module.cluster_endpoint
    cluster_ca_certificate = base64decode(local.eks_module.cluster_certificate_authority_data)
    token                  = data.terraform_remote_state.infra.outputs.eks_token
  }
}

provider "aws" {
  region = local.aws_region
}

terraform {
  required_version = ">= 1.9.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}