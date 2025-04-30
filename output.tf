
#######################
###### GENERAL ########
#######################

output "tags" {
  value       = var.tags
  description = "A map of tags that is applied to all resources created by this Terraform configuration. These tags are used consistently across all modules for resource identification, cost allocation, access control, and operational purposes. They typically include information such as environment, project, and other relevant metadata."
}

output "environment" {
  value       = var.environment
  description = "The deployment environment (e.g., dev, staging, prod) for this infrastructure."
}

########################
## ArgoCD Privatelink ##
########################

output "argocd_vpc_endpoint_service_domain_verification_name" {
  value = var.argocd_config.privatelink.enabled ? aws_vpc_endpoint_service.argocd_server[0].private_dns_name_configuration[0].name : null
}

output "argocd_vpc_endpoint_service_domain_verification_value" {
  value = var.argocd_config.privatelink.enabled ? aws_vpc_endpoint_service.argocd_server[0].private_dns_name_configuration[0].value : null
}

########################
## Grafana Privatelink ##
########################

output "grafana_vpc_endpoint_service_domain_verification_name" {
  value = var.grafana_privatelink_config.enabled ? aws_vpc_endpoint_service.grafana[0].private_dns_name_configuration[0].name : null
}

output "grafana_vpc_endpoint_service_domain_verification_value" {
  value = var.grafana_privatelink_config.enabled ? aws_vpc_endpoint_service.grafana[0].private_dns_name_configuration[0].value : null
}

#######################
######## ACM ##########
#######################

output "acm_certificate_domain_validation_options" {
  value       = { for k, v in module.acm : k => v.acm_certificate_domain_validation_options }
  description = "A map of ACM certificate domain validation options, keyed by certificate name (internal_acm or external_acm)."
}