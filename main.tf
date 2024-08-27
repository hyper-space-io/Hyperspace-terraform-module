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
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

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


########################
# EKS
########################

module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "~> 20.13.1"
  create                                   = var.create_eks
  cluster_name                             = local.cluster_name
  cluster_version                          = 1.28
  subnet_ids                               = slice(module.vpc.private_subnets, 0, var.num_zones)
  vpc_id                                   = module.vpc.vpc_id
  eks_managed_node_groups                  = local.eks_managed_node_groups
  self_managed_node_groups                 = local.additional_self_managed_nodes
  self_managed_node_group_defaults         = local.self_managed_node_group_defaults
  eks_managed_node_group_defaults          = local.eks_managed_node_group_defaults
  cluster_security_group_additional_rules  = local.cluster_security_group_additional_rules
  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = "true"
  cluster_endpoint_private_access          = "true"
  cluster_endpoint_public_access           = "false"
  create_kms_key                           = true
  kms_key_description                      = "EKS Secret Encryption Key"
  cloudwatch_log_group_retention_in_days   = "7"
  cluster_enabled_log_types                = local.enabled_cluster_logs
  cluster_addons                           = local.cluster_addons
  tags                                     = var.tags
  depends_on                               = [module.vpc]
}