provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.eks_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks_ca_certificate)
  token                  = data.terraform_remote_state.infra.outputs.eks_token
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.eks_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks_ca_certificate)
    token                  = data.terraform_remote_state.infra.outputs.eks_token
  }
}

provider "aws" {
  region = local.aws_region
}

terraform {
  required_version = ">= 1.0.0"
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