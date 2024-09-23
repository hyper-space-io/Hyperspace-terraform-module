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
