#######################
####### EKS ###########
#######################

output "eks" {
  description = "EKS module outputs"
  value = module.eks
}

output "ec2_tags_policy_arn" {
  description = "The ARN of the role to be assumed by Data-Node"
  value       = local.iam_policy_arns["ec2_tags"]
}

#######################
####### VPC ###########
#######################

output "vpc" {
  description = "VPC module outputs"
  value = module.vpc
}

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