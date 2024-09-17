# main.tf
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

data "terraform_remote_state" "infra" {
  backend = "remote"

  config = {
    organization = "Hyperspace_project"
    workspaces = {
      name = "Infra-module"
    }
  }
}

output "s3_endpoint_id" {
  value = data.terraform_remote_state.infra.outputs.s3_endpoint_id
  description = "kuku"
}