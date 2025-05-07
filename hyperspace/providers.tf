terraform {
  required_providers {
    tfe = {
      source = "hashicorp/tfe"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" { region = var.aws_region }

provider "kubernetes" {
  host                   = local.create_eks ? module.eks[0].cluster_endpoint : ""
  cluster_ca_certificate = local.create_eks ? base64decode(module.eks[0].cluster_certificate_authority_data) : ""
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = local.create_eks ? ["eks", "get-token", "--cluster-name", module.eks[0].cluster_name] : []
    command     = "aws"
  }
  ignore_annotations = local.create_eks ? null : ["all"]
  ignore_labels      = local.create_eks ? null : ["all"]
}

provider "helm" {
  kubernetes {
    host                   = local.create_eks ? module.eks[0].cluster_endpoint : ""
    cluster_ca_certificate = local.create_eks ? base64decode(module.eks[0].cluster_certificate_authority_data) : ""
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = local.create_eks ? ["eks", "get-token", "--cluster-name", module.eks[0].cluster_name] : []
      command     = "aws"
    }
  }
}