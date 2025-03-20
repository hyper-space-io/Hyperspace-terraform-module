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
  host                   = module.eks[0].cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks[0].cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks[0].cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks[0].cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks[0].cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks[0].cluster_name]
      command     = "aws"
    }
  }
}