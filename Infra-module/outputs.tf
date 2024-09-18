output "vpc_id" {
  description = "The unique identifier (ID) of the VPC where resources are deployed."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets within the VPC. These subnets are used for internal resources that do not require direct access from the internet."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets within the VPC. These subnets are used for resources that require direct access to the internet, such as NAT gateways or bastion hosts."
  value       = module.vpc.public_subnets
}

output "s3_endpoint_id" {
  description = "The ID of the VPC endpoint used for connecting to Amazon S3 privately, without needing to traverse the internet."
  value       = module.endpoints.endpoints["s3"].id
}

output "aws_region" {
  value       = var.aws_region
  description = "The AWS region where the VPC and all associated resources are deployed."
}

output "eks_token" {
  value       = data.aws_eks_cluster_auth.eks.token
  description = "The authentication token used for connecting to the EKS cluster. This token is sensitive and used for secure communication with the cluster."
  sensitive   = true
}

output "eks_cluster" {
  value       = module.eks
  description = "The complete object representing the EKS cluster, including configuration details and metadata about the cluster."
}

output "vpc" {
  value       = module.vpc
  description = "The complete object representing the VPC, including all associated subnets, route tables, and other VPC resources."
}
