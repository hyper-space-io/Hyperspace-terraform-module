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
    organization = var.organization
    workspaces = {
      name = var.infra_workspace_name
    }
  }
}

output "s3_endpoint_id" {
  value = data.terraform_remote_state.infra.outputs.s3_endpoint_id
  description = "kuku"
}

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


data "kubernetes_storage_class" "name" {
  metadata { name = "gp2" }
}

# Remove non encrypted default storage class
resource "kubernetes_annotations" "default_storageclass" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = "true"

  metadata {
    name = data.kubernetes_storage_class.name.metadata[0].name
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
}

resource "kubernetes_storage_class" "ebs_sc_gp3" {
  metadata {
    name = "ebs-sc-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
#   reclaim_policy      = var.storage_reclaim_policy
  parameters = {
    "csi.storage.k8s.io/fstype" = "ext4"
    encrypted                   = "true"
    type                        = "gp3"
    tagSpecification_1          = "Name={{ .PVCNamespace }}/{{ .PVCName }}"
    tagSpecification_2          = "Namespace={{ .PVCNamespace }}"
  }
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  depends_on             = [kubernetes_annotations.default_storageclass]
}