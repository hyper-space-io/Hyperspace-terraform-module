output "aws_region" {
  value       = var.aws_region
  description = "The AWS region where the VPC and all associated resources are deployed."
}

output "tags" {
  value       = local.tags
  description = "A map of tags that is applied to all resources created by this Terraform configuration. These tags are used consistently across all modules for resource identification, cost allocation, access control, and operational purposes. They typically include information such as environment, project, and other relevant metadata."
}

output "environment" {
  value       = var.environment
  description = "The deployment environment (e.g., dev, staging, prod) for this infrastructure."
}

output "tfe_workspace" {
  value       = data.tfe_workspace.current
  description = "The complete object representing the TFE workspace for the app module, including workspace configurations, policies, and associated resources."
}