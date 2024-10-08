provider "kubernetes" {
  host                   = local.eks_module.cluster_endpoint
  cluster_ca_certificate = base64decode(local.eks_module.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.eks_module.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = local.eks_module.cluster_endpoint
    cluster_ca_certificate = base64decode(local.eks_module.cluster_certificate_authority_data)
    exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.eks_module.cluster_name]
  }
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