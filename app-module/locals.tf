locals {
  infra_outputs = data.terraform_remote_state.infra.outputs
  # aws_region = data.terraform_remote_state.infra.outputs.aws_region
  # create_eks = data.terraform_remote_state.infra.outputs.create_eks
  # eks_module = data.terraform_remote_state.infra.outputs.eks_cluster
  aws_region = infra_outputs.aws_region
  create_eks = infra_outputs.create_eks
  eks_module = infra_outputs.eks_cluster
  vpc_module = infra_outputs.vpc
  alb_values = <<EOT
  vpcId: ${local.vpc_module.vpc_id}
  region: ${local.aws_region}
  EOT
}