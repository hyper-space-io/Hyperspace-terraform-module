#######################
######## AWS ##########
#######################

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

#######################
####### VPC ###########
#######################

data "aws_vpc" "existing" {
  count = local.create_vpc ? 0 : 1
  id    = var.existing_vpc_id
}

data "aws_subnet" "existing_private" {
  count = local.create_vpc ? 0 : length(var.existing_private_subnets)
  id    = var.existing_private_subnets[count.index]
}

#######################
##### Route53 #########
#######################

data "aws_route53_zone" "external" {
  count = var.create_public_zone ? 1 : 0
  tags = {
    Name = local.public_domain_name
    Type = "public"
    project = "hyperspace"
    environment = var.environment
    terraform = "true"
  }
  depends_on = [module.external_zone]
}

#######################
######## KMS ##########
#######################

data "aws_kms_key" "by_alias" {
  key_id = local.hyperspace_ami_key_alias
}

#######################
### Load Balancer #####
#######################

#### ArgoCD Privatelink ####
resource "time_sleep" "wait_for_argocd_privatelink_nlb" {
  count           = local.argocd_privatelink_enabled ? 1 : 0
  create_duration = "180s"
  depends_on      = [helm_release.argocd]
}

data "aws_lb" "argocd_privatelink_nlb" {
  count = local.argocd_privatelink_enabled ? 1 : 0
  tags = {
    "elbv2.k8s.aws/cluster"    = module.eks.cluster_name
    "service.k8s.aws/resource" = "LoadBalancer"
    "service.k8s.aws/stack"    = "argocd/argocd-server"
  }

  depends_on = [time_sleep.wait_for_argocd_privatelink_nlb]
}

#### Grafana Privatelink ####
resource "time_sleep" "wait_for_grafana_privatelink_nlb" {
  count           = local.grafana_privatelink_enabled ? 1 : 0
  create_duration = "180s"
  depends_on      = [helm_release.grafana]
}

data "aws_lb" "grafana_privatelink_nlb" {
  count = local.grafana_privatelink_enabled ? 1 : 0
  tags = {
    "elbv2.k8s.aws/cluster"    = module.eks.cluster_name
    "service.k8s.aws/resource" = "LoadBalancer"
    "service.k8s.aws/stack"    = "monitoring/grafana"
  }

  depends_on = [time_sleep.wait_for_grafana_privatelink_nlb]
}

#######################
###### ArgoCD #########
#######################
# GitHub
data "aws_secretsmanager_secret_version" "argocd_github_app" {
  count     = local.github_vcs_app_enabled ? 1 : 0
  secret_id = try(local.argocd_config.vcs.github.github_app_secret_name, "argocd/github_app")
}

data "aws_secretsmanager_secret_version" "argocd_github_app_private_key" {
  count     = local.github_vcs_app_enabled ? 1 : 0
  secret_id = try(local.argocd_config.vcs.github.github_private_key_secret, "argocd/github_app_private_key")
}

# GitLab
data "aws_secretsmanager_secret_version" "argocd_gitlab_oauth" {
  count     = local.gitlab_vcs_oauth_enabled ? 1 : 0
  secret_id = try(local.argocd_config.vcs.gitlab.oauth_secret_name, "argocd/gitlab_oauth")
}

data "aws_secretsmanager_secret_version" "argocd_gitlab_credentials" {
  count     = local.gitlab_vcs_enabled ? 1 : 0
  secret_id = try(local.argocd_config.vcs.gitlab.credentials_secret_name, "argocd/gitlab_credentials")
}

#######################
######## EC2 ##########
#######################

# AMI Must start with "eks-1.31-fpga-prod" and have 'Customers' in the description
data "aws_ami" "fpga" {
  owners     = [var.hyperspace_account_id]
  name_regex = "^eks-1\\.31-fpga-prod"

  filter {
    name   = "description"
    values = ["*Customers*"]
  }
}

data "aws_iam_policy_document" "ec2_tags_control" {
  statement {
    sid       = "EC2TagsDescribe"
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "EC2TagsCreate"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    effect    = "Allow"
  }
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

#######################
######### EKS #########
#######################

data "aws_lb" "internal_ingress" {
  count = var.create_eks ? 1 : 0
  tags = {
    "Domain"                   = "internal"
    "elbv2.k8s.aws/cluster"    = module.eks.cluster_name
    "ingress.k8s.aws/resource" = "LoadBalancer"
  }
  depends_on = [time_sleep.wait_for_internal_ingress, module.eks, kubernetes_ingress_v1.nginx_ingress]
}

data "aws_lb" "external_ingress" {
  count = var.create_eks && var.create_public_zone ? 1 : 0
  tags = {
    "Domain"                   = "external"
    "elbv2.k8s.aws/cluster"    = module.eks.cluster_name
    "ingress.k8s.aws/resource" = "LoadBalancer"
  }
  depends_on = [time_sleep.wait_for_external_ingress, module.eks, kubernetes_ingress_v1.nginx_ingress]
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid = "AutoscalingWrite"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]
    resources = [
      "arn:aws:autoscaling:${var.aws_region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/*",
    ]
    effect = "Allow"
  }

  statement {
    sid = "AutoscalingRead"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags"
    ]
    resources = ["*"]
    effect    = "Allow"
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
    effect    = "Allow"
  }

  statement {
    sid = "EKSDescribe"
    actions = [
      "eks:DescribeNodegroup"
    ]
    resources = [
      "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:nodegroup/${local.cluster_name}/*"
    ]
    effect = "Allow"
  }
}

#######################
######### S3 ##########
#######################
data "aws_iam_policy_document" "core_dump_s3_full_access" {
  statement {
    sid = "FullAccessS3CoreDump"
    actions = [
      "s3:*"
    ]
    resources = [
      module.s3_buckets["core-dump-logs"].s3_bucket_arn,
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
      module.s3_buckets["velero"].s3_bucket_arn,
      "${module.s3_buckets["velero"].s3_bucket_arn}/*"
    ]
    effect = "Allow"
  }
}

#######################
####### Loki ##########
#######################
data "aws_iam_policy_document" "loki_s3_dynamodb_full_access" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject"
    ]
    effect = "Allow"
    resources = [
      module.s3_buckets["loki"].s3_bucket_arn,
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
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${local.cluster_name}-loki-index-*"
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

#######################
## Secrets Manager ####
#######################
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