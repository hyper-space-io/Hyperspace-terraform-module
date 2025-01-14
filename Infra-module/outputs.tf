output "aws_region" {
  value       = var.aws_region
  description = "The AWS region where the VPC and all associated resources are deployed."
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

output "iam_roles" {
  value       = module.iam_iam-assumable-role-with-oidc
  description = "The complete set of IAM roles created for OIDC authentication, including role configurations, trust relationships, and attached policies."
}

output "iam_policies" {
  value       = aws_iam_policy.policies
  description = "The complete set of IAM policies created for the infrastructure, including policy documents, ARNs, and attachment details."
}

output "tfe_organizations" {
  value       = data.tfe_organizations.foo
  description = "The complete set of TFE organizations created for the infrastructure, including organization configurations, trust relationships, and attached policies."
}
