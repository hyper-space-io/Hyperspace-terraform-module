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
          "iam:GetInstanceProfile",
          "iam:ListAttachedRolePolicies",
          "iam:ListUserPolicies",
          "iam:GetUserPolicy",
          "iam:GetUser",
          "iam:ListUsers"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy",
          "iam:CreateRole",
          "iam:DeletePolicy",
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
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupReferences",
          "ec2:DescribeSecurityGroupRules"
        ]
        Resource = "*"
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
          "ForAnyValue:StringLike" : {
            "aws:ResourceTag/environment" : "${var.environment}",
            "aws:ResourceTag/project" : "${var.project}"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:ListKeys",
          "kms:ListAliases"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:TagResource",
          "kms:DescribeKey",
          "kms:DeleteKey",
          "kms:ScheduleKeyDeletion",
          "kms:CreateAlias"
        ]
        Resource = "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          "ForAnyValue:StringLike" : {
            "aws:ResourceTag/environment" : "${var.environment}",
            "aws:ResourceTag/project" : "${var.project}"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:GetChange",
          "route53:GetHostedZone",
          "route53:ListHostedZonesByName",
          "route53:CreateHostedZone",
          "route53:ChangeResourceRecordSets",
          "route53:ChangeTagsForResource"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/*",
          "arn:aws:route53:::change/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "eks:CreateCluster",
          "eks:DescribeCluster",
          "eks:DeleteCluster",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:DescribeUpdate"
        ]
        Resource = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/*"
        Condition = {
          "ForAnyValue:StringLike" : {
            "aws:ResourceTag/environment" : "${var.environment}",
            "aws:ResourceTag/project" : "${var.project}"
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