########################
## ArgoCD Privatelink ##
########################

output "argocd_vpc_endpoint_service_domain_verification_name" {
  value = module.hyperspace.argocd_vpc_endpoint_service_domain_verification_name
}

output "argocd_vpc_endpoint_service_domain_verification_value" {
  value = module.hyperspace.argocd_vpc_endpoint_service_domain_verification_value
}

#########################
## Grafana Privatelink ##
#########################

output "grafana_vpc_endpoint_service_domain_verification_name" {
  value = module.hyperspace.grafana_vpc_endpoint_service_domain_verification_name
}

output "grafana_vpc_endpoint_service_domain_verification_value" {
  value = module.hyperspace.grafana_vpc_endpoint_service_domain_verification_value
}

#######################
######## ACM ##########
#######################

output "acm_certificate_domain_validation_options" {
  value       = module.hyperspace.acm_certificate_domain_validation_options
  description = "A map of ACM certificate domain validation options, keyed by certificate name (internal_acm or external_acm)."
}