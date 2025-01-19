locals {
  app_module_variables = {
    create_public_zone = var.create_public_zone
    dex_connectors = jsonencode(var.dex_connectors)
    domain_name = var.domain_name
    enable_ha_argocd = var.enable_ha_argocd
    infra_workspace_name = terraform.workspace
    organization = data.tfe_organizations.all.names[0]
    project = var.project
    environment = var.environment
    create_eks = var.create_eks
    worker_nodes_max = var.worker_nodes_max
    worker_instance_type = jsonencode(var.worker_instance_type)
    availability_zones = jsonencode(local.availability_zones)
    aws_region = var.aws_region
    data_node_ami_id = data.aws_ami.fpga.id
    tags = base64encode(var.tags)
    vpc_module = base64encode(module.vpc)
    s3_buckets = base64encode(module.s3_buckets)  
    iam_roles = base64encode(module.iam_roles)
    iam_policies = base64encode(module.iam_policies)
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
  value = each.value
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

resource "tfe_workspace_settings" "Infra-settings" {
  workspace_id = data.tfe_workspace.current.id
  remote_state_consumer_ids = [tfe_workspace.app.id]
}