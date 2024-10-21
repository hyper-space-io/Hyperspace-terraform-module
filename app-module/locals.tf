locals {
  tags         = data.terraform_remote_state.infra.outputs.tags
  aws_region   = data.terraform_remote_state.infra.outputs.aws_region
  environment  = data.terraform_remote_state.infra.outputs.environment
  eks_module   = data.terraform_remote_state.infra.outputs.eks_cluster
  vpc_module   = data.terraform_remote_state.infra.outputs.vpc
  s3_buckets   = data.terraform_remote_state.infra.outputs.s3_buckets
  iam_roles    = data.terraform_remote_state.infra.outputs.iam_roles
  iam_policies = data.terraform_remote_state.infra.outputs.iam_policies
  alb_values   = <<EOT
  vpcId: ${local.vpc_module.vpc_id}
  region: ${local.aws_region}
  EOT
}