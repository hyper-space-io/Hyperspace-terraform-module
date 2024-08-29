data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

data "kubernetes_storage_class" "name" {
  metadata { name = "gp2" }
  depends_on = [module.eks]
}

data "aws_eks_cluster" "main" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = data.aws_eks_cluster.main.name
}

data "aws_iam_policy_document" "fpga_pull_access" {
  statement {
    sid = "PullAccessAGFI"
    actions = [
      "ec2:DeleteFpgaImage",
      "ec2:DescribeFpgaImages",
      "ec2:ModifyFpgaImageAttribute",
      "ec2:CreateFpgaImage",
      "ec2:DescribeFpgaImageAttribute",
      "ec2:CopyFpgaImage",
      "ec2:ResetFpgaImageAttribute",
      "kms:*"
    ]
    resources = [
      "arn:aws:ec2:${var.aws_region}::*",
      "arn:aws:kms:${var.aws_region}::*",
    ]
    effect = "Allow"
  }
}