output "aws_region" {
  value       = var.aws_region
  description = "The AWS region where the VPC and all associated resources are deployed."
}

output "eks_token" {
  value       = data.aws_eks_cluster_auth.eks.token
  sensitive   = true
  description = "The authentication token used for connecting to the EKS cluster. This token is sensitive and used for secure communication with the cluster."
}

output "eks_cluster" {
  value       = module.eks
  description = "The complete object representing the EKS cluster, including configuration details and metadata about the cluster."
}

output "vpc" {
  value       = module.vpc
  description = "The complete object representing the VPC, including all associated subnets, route tables, and other VPC resources."
}

output "tags" {
  value       = local.tags
  description = "A map of tags that is applied to all resources created by this Terraform configuration. These tags are used consistently across all modules for resource identification, cost allocation, access control, and operational purposes. They typically include information such as environment, project, and other relevant metadata."
}

output "s3_buckets" {
  value       = module.s3_buckets
  description = "The complete object representing all S3 buckets created by the S3 module, including bucket configurations, policies, and associated resources."
}

output "environment" {
  value       = var.environment
  description = "The deployment environment (e.g., dev, staging, prod) for this infrastructure."
}