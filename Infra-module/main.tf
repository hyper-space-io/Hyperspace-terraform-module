# NETWORKING

module "vpc" {
  source                                          = "terraform-aws-modules/vpc/aws"
  version                                         = "~>5.13.0"
  name                                            = "${var.project}-${var.environment}-vpc"
  cidr                                            = var.vpc_cidr
  azs                                             = local.availability_zones
  private_subnets                                 = local.private_subnets
  public_subnets                                  = local.public_subnets
  create_database_subnet_group                    = false
  enable_nat_gateway                              = var.enable_nat_gateway
  single_nat_gateway                              = var.single_nat_gateway
  one_nat_gateway_per_az                          = !var.single_nat_gateway
  map_public_ip_on_launch                         = true
  enable_dns_hostnames                            = true
  manage_default_security_group                   = true
  enable_flow_log                                 = var.create_vpc_flow_logs
  vpc_flow_log_tags                               = var.create_vpc_flow_logs ? var.tags : null
  flow_log_destination_type                       = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group            = var.create_vpc_flow_logs
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_logs_retention
  flow_log_cloudwatch_log_group_class             = var.flow_log_group_class
  create_flow_log_cloudwatch_iam_role             = var.create_vpc_flow_logs
  flow_log_file_format                            = var.flow_log_file_format
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "Type"                   = "public"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "Type"                            = "private"
  }
  tags = var.tags
}

module "endpoints" {
  source                     = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version                    = "~>5.13.0"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnets
  create_security_group      = true
  security_group_name_prefix = var.project
  security_group_description = "VPC endpoint security group"

  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  endpoints = {
    s3 = {
      service             = "s3"
      private_dns_enabled = true
      dns_options = {
        private_dns_only_for_inbound_resolver_endpoint = false
      }
      tags = merge(var.tags, {
        Name = "Hyperspace S3 Endpoint"
      })
    }
  }
  tags = var.tags
}

# EKS

module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "~> 20.13.1"
  create                                   = var.create_eks
  cluster_name                             = local.cluster_name
  cluster_version                          = var.kubernetes_version
  subnet_ids                               = slice(module.vpc.private_subnets, 0, var.num_zones)
  vpc_id                                   = module.vpc.vpc_id
  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = "true"
  cluster_endpoint_private_access          = "true"
  cluster_endpoint_public_access           = "false"
  eks_managed_node_groups                  = var.additional_managed_node_pools
  self_managed_node_groups                 = local.additional_self_managed_nodes
  create_kms_key                           = true
  kms_key_description                      = "EKS Secret Encryption Key"
  cloudwatch_log_group_retention_in_days   = "7"
  cluster_enabled_log_types                = local.enabled_cluster_logs
  tags                                     = var.tags
  cluster_addons                           = var.cluster_addons
  cluster_security_group_additional_rules = {
    recieve_traffic_from_vpc = {
      description = "traffic from whole vpc"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = [var.vpc_cidr]
    }
  }
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    cluster_nodes_incoming = {
      description                   = "allow from cluster To node 1025-65535"
      protocol                      = "tcp"
      from_port                     = 1025
      to_port                       = 65535
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  self_managed_node_group_defaults = {
    update_launch_template_default_version = true
    iam_role_use_name_prefix               = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      AmazonEBSCSIDriverPolicy     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
      Additional                   = "${aws_iam_policy.this.arn}"
    }
  }
  eks_managed_node_group_defaults = {
    update_launch_template_default_version = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      AmazonEBSCSIDriverPolicy     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    },
    subnets = slice(module.vpc.private_subnets, 0, var.num_zones)
    tags = {
      "k8s.io/cluster-autoscaler/enabled"               = "True"
      "k8s.io/cluster-autoscaler/${local.cluster_name}" = "True"
      "Name"                                            = "${local.cluster_name}"
    }
  }
  depends_on = [module.vpc]
}

# TFC AGENT
resource "aws_instance" "tfc_agent" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.medium"
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.tfc_agent_sg.id]
  user_data = templatefile("user_data.sh.tpl", {
    tfc_agent_token = var.tfc_agent_token
  })
  tags = {
    Name = "tfc-agent"
  }
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
  }
}