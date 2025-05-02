########################
## ArgoCD Privatelink ##
########################

output "argocd_vpc_endpoint_service_domain_verification_name" {
  value = local.argocd_privatelink_enabled ? aws_vpc_endpoint_service.argocd[0].private_dns_name_configuration[0].name : null
}

output "argocd_vpc_endpoint_service_domain_verification_value" {
  value = local.argocd_privatelink_enabled ? aws_vpc_endpoint_service.argocd[0].private_dns_name_configuration[0].value : null
}

########################
## Grafana Privatelink ##
########################

output "grafana_vpc_endpoint_service_domain_verification_name" {
  value = local.grafana_privatelink_enabled ? aws_vpc_endpoint_service.grafana[0].private_dns_name_configuration[0].name : null
}

output "grafana_vpc_endpoint_service_domain_verification_value" {
  value = local.grafana_privatelink_enabled ? aws_vpc_endpoint_service.grafana[0].private_dns_name_configuration[0].value : null
}

#######################
######## ACM ##########
#######################

output "acm_certificate_domain_validation_options" {
  value       = { for k, v in module.acm : k => v.acm_certificate_domain_validation_options }
  description = "A map of ACM certificate domain validation options, keyed by certificate name (internal_acm or external_acm)."
}


#######################
####### EKS ###########
#######################

