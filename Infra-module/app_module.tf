locals {
  app_module_variables = {
    project                                    = var.project
    environment                                = var.environment
    aws_region                                 = var.aws_region
    hyperspace_account_id                      = var.hyperspace_account_id
    tags                                       = jsonencode(local.tags)
    domain_name                                = var.domain_name
    infra_workspace_name                       = terraform.workspace
    organization                               = data.tfe_organizations.all.names[0]
    vpc_module                                 = jsonencode(module.vpc)
    availability_zones                         = jsonencode(local.availability_zones)
    s3_buckets_arns                            = jsonencode({ for k, v in module.s3_buckets : k => v.s3_bucket_arn })
    s3_buckets_names                           = jsonencode({ for k, v in module.s3_buckets : k => v.s3_bucket_id })
    iam_policies                               = jsonencode({ for k, v in aws_iam_policy.policies : k => v })
    local_iam_policies                         = jsonencode({ for k, v in local.iam_policies : k => v })
    create_eks                                 = var.create_eks
    worker_nodes_max                           = var.worker_nodes_max
    worker_instance_type                       = jsonencode(var.worker_instance_type)
    data_node_ami_id                           = data.aws_ami.fpga.id
    enable_ha_argocd                           = var.enable_ha_argocd
    create_public_zone                         = var.create_public_zone
    dex_connectors                             = jsonencode(var.dex_connectors)
    argocd_endpoint_allowed_principals         = jsonencode(var.argocd_endpoint_allowed_principals)
    argocd_endpoint_additional_aws_regions     = jsonencode(var.argocd_endpoint_additional_aws_regions)
    prometheus_endpoint_service_name           = var.prometheus_endpoint_service_name
    prometheus_endpoint_service_region         = var.prometheus_endpoint_service_region
    prometheus_endpoint_additional_cidr_blocks = jsonencode(var.prometheus_endpoint_additional_cidr_blocks)
  }
}

resource "tfe_workspace" "app" {
  name         = "hyperspace-app-module"
  organization = data.tfe_organizations.all.names[0]
  project_id   = data.tfe_workspace.current.project_id
  vcs_repo {
    identifier     = "hyper-space-io/Hyperspace-terraform-module"
    branch         = "simulation"
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
  for_each     = local.app_module_variables
  key          = each.key
  value        = each.value
  category     = "terraform"
  description  = "app-module-variable"
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
  workspace_id              = data.tfe_workspace.current.id
  remote_state_consumer_ids = [tfe_workspace.app.id]
}

output "tfe_oauth_client" {
  value = data.tfe_oauth_client.client
}

output "tfe_organizations" {
  value = data.tfe_organizations.all.names[0]
}

output "tfe_workspace" {
  value = data.tfe_workspace.current.id
}