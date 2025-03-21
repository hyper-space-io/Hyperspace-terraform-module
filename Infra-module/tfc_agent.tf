resource "aws_instance" "tfc_agent" {
  ebs_optimized          = true
  monitoring             = true
  instance_type          = "t3.medium"
  ami                    = data.aws_ami.amazon_linux_2.id
  subnet_id              = module.vpc.private_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.tfc_agent_profile.name
  vpc_security_group_ids = [aws_security_group.tfc_agent_sg.id]
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    tfc_agent_token = tfe_agent_token.app-agent-token.token
  })
  tags = {
    Name = "tfc-agent"
  }
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2 # Enables Containers on EC2 to access instance metadata
    instance_metadata_tags      = "enabled"
  }
}

resource "aws_iam_role" "tfc_agent_role" {
  name = "tfc-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "tfc_agent_iam_policy" {
  name = "tfc-agent-iam-policy"
  role = aws_iam_role.tfc_agent_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:ListRoles",
          "iam:GetPolicy",
          "iam:GetRolePolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicies",
          "iam:ListPolicyVersions",
          "iam:ListRolePolicies",
          "iam:ListInstanceProfiles",
          "iam:ListInstanceProfilesForRole",
          "iam:GetInstanceProfile",
          "iam:ListAttachedRolePolicies",
          "iam:ListUserPolicies",
          "iam:GetUserPolicy",
          "iam:GetUser",
          "iam:ListUsers",
          "iam:CreateOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupReferences",
          "ec2:DescribeSecurityGroupRules",
          "ec2:CreateLaunchTemplate",
          "ec2:DescribeLaunchTemplates",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DeleteLaunchTemplateVersions",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "kms:CreateKey",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:ListKeys",
          "kms:ListAliases",
          "route53:ListHostedZones",
          "route53:DeleteHostedZone",
          "route53:ListResourceRecordSets",
          "route53:GetChange",
          "route53:GetHostedZone",
          "route53:ListHostedZonesByName",
          "route53:CreateHostedZone",
          "route53:ChangeResourceRecordSets",
          "route53:ListTagsForResource",
          "route53:ChangeTagsForResource",
          "eks:DescribeAddonVersions",
          "eks:CreateAddon",
          "eks:DeleteAddon",
          "eks:UpdateAddon",
          "eks:DescribeAddonConfiguration",
          "eks:DescribeAddon",
          "eks:ListAddons",
          "eks:GetAddon",
          "eks:DescribeNodegroup",
          "eks:DescribeAccessEntry",
          "eks:ListAssociatedAccessPolicies",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeSSLPolicies",
          "ec2:CreateVpcEndpointServiceConfiguration",
          "ec2:DescribeVpcEndpointServiceConfigurations",
          "ec2:ModifyVpcEndpointServiceConfiguration",
          "ec2:DeleteVpcEndpointServiceConfigurations",
          "ec2:DescribeVpcEndpointServicePermissions",
          "ec2:ModifyVpcEndpointServicePermissions",
          "ec2:DescribeVpcEndpointServiceConfigurations",
          "ecr:GetAuthorizationToken",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:GetRegistryPolicy",
          "ecr:GetRegistryScanningConfiguration",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:BatchImportUpstreamImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetImageCopyStatus",
          "autoscaling:DescribeScalingActivities"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy",
          "iam:CreateRole",
          "iam:DeletePolicy",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:PassRole",
          "iam:PutRolePolicy",
          "iam:TagRole",
          "iam:TagPolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:TagInstanceProfile"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress"
        ]
        Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-group/*"
      },
      {
        Effect = "Allow"
        Action = [
          "acm:RequestCertificate",
          "acm:DescribeCertificate",
          "acm:DeleteCertificate",
          "acm:ListCertificates",
          "acm:AddTagsToCertificate",
          "acm:ListTagsForCertificate"
        ]
        Resource = "arn:aws:acm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:certificate/*"
        Condition = {
          "ForAnyValue:StringLike" = {
            "aws:ResourceTag/environment" : ["${var.environment}"],
            "aws:ResourceTag/project" : ["${var.project}"]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:TagResource",
          "kms:DescribeKey",
          "kms:DeleteKey",
          "kms:ScheduleKeyDeletion"
        ]
        Resource = [
          "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*",
          "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/*"
        ]
        Condition = {
          "ForAnyValue:StringLike" = {
            "aws:ResourceTag/environment" : ["${var.environment}"],
            "aws:ResourceTag/project" : ["${var.project}"]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "eks:CreateCluster",
          "eks:TagResource",
          "eks:DescribeCluster",
          "eks:DeleteCluster",
          "eks:CreateAccessEntry",
          "eks:DeleteAccessEntry",
          "eks:ListAccessEntries",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:CreateNodegroup",
          "eks:DeleteNodegroup",
          "eks:DescribeUpdate",
          "eks:AssociateAccessPolicy",
          "eks:DisassociateAccessPolicy",
          "eks:UpdateNodegroupConfig",
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:DeleteAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = [
          "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/*",
          "arn:aws:autoscaling:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/*",
          "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:access-entry/*",
          "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:nodegroup/*"
        ]
        Condition = {
          "ForAnyValue:StringLike" = {
            "aws:ResourceTag/environment" : ["${var.environment}"],
            "aws:ResourceTag/project" : ["${var.project}"]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "tfc_agent_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM",
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  ])
  policy_arn = each.value
  role       = aws_iam_role.tfc_agent_role.name
}

resource "aws_iam_instance_profile" "tfc_agent_profile" {
  name = "tfc-agent-profile"
  role = aws_iam_role.tfc_agent_role.name
}

resource "aws_security_group" "tfc_agent_sg" {
  name        = "tfc-agent-sg"
  description = "Security group for Terraform Cloud Agent"
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all egress traffic"
  }
}