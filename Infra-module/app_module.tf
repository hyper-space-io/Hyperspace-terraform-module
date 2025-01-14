resource "tfe_workspace" "app" {
  name         = "hyperspace-app-module"
  organization = data.tfe_organizations.foo.names[0]
}

resource "tfe_agent_pool" "app-agent-pool" {
  name         = "hyperspace-app-agent-pool"
  organization = data.tfe_organizations.foo.name
}

resource "tfe_agent_pool_allowed_workspaces" "app" {
  agent_pool_id         = tfe_agent_pool.app-agent-pool.id
  allowed_workspace_ids = [tfe_workspace.app.id]
}

resource "tfe_workspace_settings" "app-settings" {
  workspace_id   = tfe_workspace.app.id
  agent_pool_id  = tfe_agent_pool_allowed_workspaces.app.agent_pool_id
  execution_mode = "agent"
}