locals {
  eks_exec_args = concat(
    [
      "eks",
      "get-token",
      "--cluster-name",
      local.cluster_name,
      "--region",
      var.aws_region
    ],
    var.terraform_role != null ? [
      "--role-arn",
      "arn:aws:iam::${var.aws_account_id}:role/${var.terraform_role}"
    ] : []
  )
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.90.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.37.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  dynamic "assume_role" {
    for_each = var.terraform_role != null ? [1] : []
    content {
      role_arn     = "arn:aws:iam::${var.aws_account_id}:role/${var.terraform_role}"
      session_name = "terraform"
    }
  }
}

provider "kubernetes" {
  host                   = var.create_eks ? module.eks.cluster_endpoint : null
  cluster_ca_certificate = var.create_eks ? base64decode(module.eks.cluster_certificate_authority_data) : null
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = local.eks_exec_args
  }
}

provider "helm" {
  kubernetes {
    host                   = var.create_eks ? module.eks.cluster_endpoint : null
    cluster_ca_certificate = var.create_eks ? base64decode(module.eks.cluster_certificate_authority_data) : null
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = local.eks_exec_args
    }
  }
}

provider "helm" {
  alias = "karpenter"
  kubernetes {
    host                   = var.create_eks ? module.eks.cluster_endpoint : null
    cluster_ca_certificate = var.create_eks ? base64decode(module.eks.cluster_certificate_authority_data) : null

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", local.cluster_name]
    }
  }

  # Registry configuration for accessing AWS ECR Public Gallery
  # Uses authentication token from data source
  registry {
    url      = "oci://public.ecr.aws"
    username = var.create_eks ? data.aws_ecrpublic_authorization_token.token.user_name : null
    password = var.create_eks ? data.aws_ecrpublic_authorization_token.token.password : null
  }
}
