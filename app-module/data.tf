data "terraform_remote_state" "infra" {
  backend = "remote"

  config = {
    organization = var.organization
    workspaces = {
      name = var.infra_workspace_name
    }
  }
}

data "kubernetes_storage_class" "name" {
  metadata { name = "gp2" }
}