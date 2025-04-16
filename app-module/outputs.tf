output "aws_vpc_endpoint_service_domain_verification_name" {
  value = aws_vpc_endpoint_service.argocd_server[0].private_dns_name_configuration[0].name
}


output "aws_vpc_endpoint_service_domain_verification_value" {
  value = aws_vpc_endpoint_service.argocd_server[0].private_dns_name_configuration[0].value
}