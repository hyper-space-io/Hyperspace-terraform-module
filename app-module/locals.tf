locals {
  aws_region = data.terraform_remote_state.infra.outputs.aws_region
  eks_module = data.terraform_remote_state.infra.outputs.eks_cluster
  vpc_module = data.terraform_remote_state.infra.outputs.vpc
  alb_values = <<EOT
  vpcId: ${local.vpc_module.vpc_id}
  region: ${local.aws_region}
  EOT
}