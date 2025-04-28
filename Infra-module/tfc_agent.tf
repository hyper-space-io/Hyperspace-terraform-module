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
  tags = merge(var.tags, {
    Name = "tfc-agent"
  })
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
          "iam:Get*",
          "iam:List*",
          "iam:CreateOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider"
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
          "iam:Tag*",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:AddRoleToInstanceProfile"
        ]
        Resource = [
          "arn:aws:iam::*:role/*",
          "arn:aws:iam::*:policy/*",
          "arn:aws:iam::*:instance-profile/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:DeleteLaunchTemplateVersions",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:CreateVpcEndpointServiceConfiguration",
          "ec2:ModifyVpcEndpointServiceConfiguration",
          "ec2:DeleteVpcEndpointServiceConfigurations",
          "ec2:ModifyVpcEndpointServicePermissions",
          "ec2:CreateVpcEndpoint",
          "ec2:DeleteVpcEndpoints",
          "ec2:ModifyVpcEndpoint",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeRouteTables",
          "ec2:DescribeVpcEndpointServices",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeVpcEndpointConnections",
          "ec2:AcceptVpcEndpointConnections",
          "ec2:RejectVpcEndpointConnections",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "vpce:AllowMultiRegion"
        ]
        Resource = [
          "*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc-endpoint/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subnet/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:route-table/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "eks:*",
          "eks-auth:*",
          "eks:DescribeAddonVersions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:Describe*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:Get*",
          "ecr:List*",
          "ecr:Describe*",
          "ecr:BatchCheck*",
          "ecr:BatchGet*",
          "ecr:BatchImportUpstreamImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:ListKeys",
          "kms:ListAliases",
          "kms:TagResource",
          "kms:DescribeKey",
          "kms:ScheduleKeyDeletion"
        ]
        Resource = [
          "*",
          "arn:aws:kms:*:*:key/*",
          "arn:aws:kms:*:*:alias/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:DeleteHostedZone",
          "route53:ListResourceRecordSets",
          "route53:GetChange",
          "route53:GetHostedZone",
          "route53:ListHostedZonesByName",
          "route53:CreateHostedZone",
          "route53:ChangeResourceRecordSets",
          "route53:ListTagsForResource",
          "route53:AssociateVPCWithHostedZone",
          "route53:DisassociateVPCFromHostedZone",
          "route53:ChangeTagsForResource"
        ]
        Resource = "*"
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
        Resource = "arn:aws:acm:*:*:certificate/*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:DeleteAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:DescribeScalingActivities"
        ]
        Resource = "*"
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
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
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