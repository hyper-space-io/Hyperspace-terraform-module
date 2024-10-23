data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# FPGA pull access for EC2
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

# Cluster Autoscaler
data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid = "Autoscaling"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeImages",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup"
    ]
    resources = [
      "*",
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "core_dump_s3_full_access" {
  statement {
    sid = "FullAccessS3CoreDump"
    actions = [
      "s3:*"
    ]
    resources = [
      "${module.s3_buckets["core-dump-logs"].s3_bucket_arn}",
      "${module.s3_buckets["core-dump-logs"].s3_bucket_arn}/*"
    ]
    effect = "Allow"
  }
}