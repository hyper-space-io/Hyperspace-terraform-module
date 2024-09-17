output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "s3_endpoint_id" {
  description = "The ID of the S3 VPC endpoint"
  value       = module.endpoints.endpoints["s3"].id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS cluster endpoint"
}

output "eks_ca_certificate" {
  value       = module.eks.cluster_certificate_authority_data
  description = "EKS cluster CA certificate"
}

output "eks_token" {
  value       = data.aws_eks_cluster_auth.eks.token
  description = "EKS authentication token"
  sensitive   = true
}