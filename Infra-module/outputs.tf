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

output "aws_region" {
  value = var.aws_region
  description = "aws region"
}

output "eks_token" {
  value       = data.aws_eks_cluster_auth.eks.token
  description = "EKS authentication token"
  sensitive   = true
}

output "eks_cluster" {
  value = module.eks
  description = "The whole eks cluster object"
}

output "vpc" {
  value = module.vpc
  description = "The whole VPC object"
}