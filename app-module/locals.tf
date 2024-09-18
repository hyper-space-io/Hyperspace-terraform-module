locals {
  aws_region = data.terraform_remote_state.infra.outputs.aws_region
  create_eks = data.terraform_remote_state.infra.outputs.create_eks
  eks_module = data.terraform_remote_state.infra.outputs.eks_cluster
  alb_values = <<EOT
  vpcId: ${module.vpc.vpc_id}
  region: ${local.aws_region}
  EOT
}