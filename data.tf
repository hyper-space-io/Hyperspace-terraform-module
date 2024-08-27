data "aws_availability_zones" "available" {
  state = "available"
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
      "*",
    ]
    effect = "Allow"
  }
}