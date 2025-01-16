locals {
  app_module_variables = {
    create_public_zone = {value = var.create_public_zone}
    dex_connectors = {value = jsonencode(var.dex_connectors)}
    domain_name = {value = var.domain_name}
    enable_ha_argocd = {value = var.enable_ha_argocd}
    infra_workspace_name = {value = terraform.workspace, hcl = true}
    organization = {value = data.tfe_organizations.all.names[0], hcl = true}
  }
}
resource "tfe_workspace" "app" {
  name         = "hyperspace-app-module"
  organization = data.tfe_organizations.all.names[0]
  project_id   = data.tfe_workspace.current.project_id
  vcs_repo {
    identifier = "hyper-space-io/Hyperspace-terraform-module"
    branch = "setup-cluster-tools"
    oauth_token_id = data.tfe_workspace.current.vcs_repo[0].oauth_token_id
  }
  working_directory = "app-module"
}

resource "tfe_workspace_settings" "app-settings" {
  workspace_id   = tfe_workspace.app.id
  agent_pool_id  = tfe_agent_pool_allowed_workspaces.app.agent_pool_id
  execution_mode = "agent"
}

resource "tfe_variable" "app-variables" {
  for_each = local.app_module_variables
  key = each.key
  value = "${each.value.value}"
  hcl = try(each.value.hcl, false)
  category = "terraform"
  description = "app-module-variable"
  workspace_id = tfe_workspace.app.id
}

resource "tfe_agent_pool" "app-agent-pool" {
  name         = "hyperspace-app-agent-pool"
  organization = data.tfe_organizations.all.names[0]
}

resource "tfe_agent_pool_allowed_workspaces" "app" {
  agent_pool_id         = tfe_agent_pool.app-agent-pool.id
  allowed_workspace_ids = [tfe_workspace.app.id]
}

resource "tfe_agent_token" "app-agent-token" {
  agent_pool_id = tfe_agent_pool.app-agent-pool.id
  description   = "app-agent-token"
}
