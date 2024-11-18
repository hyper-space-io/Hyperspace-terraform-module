data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

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
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]
    resources = [
      "arn:aws:autoscaling:${var.aws_region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${module.eks.cluster_name}-*"
    ]
    effect = "Allow"
  }

  statement {
    sid = "EC2Describe"
    actions = [
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeImages",
      "ec2:GetInstanceTypesFromInstanceRequirements"
    ]
    resources = ["*"]
    effect = "Allow"
  }

  statement {
    sid = "EKSDescribe"
    actions = [
      "eks:DescribeNodegroup"
    ]
    resources = [
      "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:nodegroup/${module.eks.cluster_name}/*"
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

data "aws_iam_policy_document" "velero_s3_full_access" {
  statement {
    sid = "FullAccessS3CoreDump"
    actions = [
      "s3:*"
    ]
    resources = [
      "${module.s3_buckets["velero"].s3_bucket_arn}",
      "${module.s3_buckets["velero"].s3_bucket_arn}/*"
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "ec2_tags_control" {
  statement {
    sid = "EC2TagsAccess"
    actions = [
      "ec2:DescribeTags",
      "ec2:CreateTags"
    ]
    resources = [
      "arn:aws:ec2:*:*:instance/*"
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "loki_s3_dynamodb_full_access" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject"
    ]
    effect = "Allow"
    resources = [
      "${module.s3_buckets["loki"].s3_bucket_arn}",
      "${module.s3_buckets["loki"].s3_bucket_arn}/*"
    ]
  }
  statement {
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:ListTagsOfResource",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:UpdateItem",
      "dynamodb:UpdateTable",
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${module.eks.cluster_name}-loki-index-*"
    ]
  }
  statement {
    actions = [
      "dynamodb:ListTables"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions = [
      "application-autoscaling:DescribeScalableTargets",
      "application-autoscaling:DescribeScalingPolicies",
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:PutScalingPolicy",
      "application-autoscaling:DeleteScalingPolicy"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions = [
      "iam:GetRole",
      "iam:PassRole"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.cluster_name}-loki"
    ]
  }
}

data "aws_iam_policy_document" "secrets_manager" {
  statement {
    sid = "secretsmanager"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:*",
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"

    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowUseOfTheKey"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowAttachmentOfPersistentResources"
    effect = "Allow"

    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}