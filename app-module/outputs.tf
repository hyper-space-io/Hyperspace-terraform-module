########################
## ArgoCD Privatelink ##
########################

output "argocd_vpc_endpoint_service_domain_verification_name" {
  value = aws_vpc_endpoint_service.argocd_server[0].private_dns_name_configuration[0].name
}

output "argocd_vpc_endpoint_service_domain_verification_value" {
  value = aws_vpc_endpoint_service.argocd_server[0].private_dns_name_configuration[0].value
}

########################
## Grafana Privatelink ##
########################

output "grafana_vpc_endpoint_service_domain_verification_name" {
  value = aws_vpc_endpoint_service.grafana_server[0].private_dns_name_configuration[0].name
}

output "grafana_vpc_endpoint_service_domain_verification_value" {
  value = aws_vpc_endpoint_service.grafana_server[0].private_dns_name_configuration[0].value
}

#######################
######## ACM ##########
#######################

output "acm_certificate_domain_validation_options" {
  value       = { for k, v in module.acm : k => v.acm_certificate_domain_validation_options }
  description = "A map of ACM certificate domain validation options, keyed by certificate name (internal_acm or external_acm)."
}