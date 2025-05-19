# NETWORKING
module "vpc" {
  count                                           = local.create_vpc ? 1 : 0
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
  vpc_flow_log_tags                               = var.create_vpc_flow_logs ? local.tags : null
  flow_log_destination_type                       = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group            = var.create_vpc_flow_logs
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_logs_retention
  flow_log_cloudwatch_log_group_class             = var.flow_log_group_class
  create_flow_log_cloudwatch_iam_role             = var.create_vpc_flow_logs
  flow_log_file_format                            = var.flow_log_file_format
  public_subnet_tags                              = local.public_subnet_tags
  private_subnet_tags                             = local.private_subnet_tags
  tags                                            = local.tags
}

module "endpoints" {
  source                     = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version                    = "~>5.13.0"
  vpc_id                     = local.vpc_id
  subnet_ids                 = local.private_subnets_ids
  create_security_group      = true
  security_group_name_prefix = var.project
  security_group_description = "VPC endpoint security group"

  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [local.vpc_cidr_block]
    }
  }

  endpoints = {
    s3 = {
      service             = "s3"
      private_dns_enabled = true
      dns_options = {
        private_dns_only_for_inbound_resolver_endpoint = false
      }
      tags = merge(local.tags, {
        Name = "Hyperspace S3 Endpoint"
      })
    }
  }
  tags = local.tags
}

resource "null_resource" "validate_subnet_tags" {
  count = local.create_vpc ? 0 : 1

  triggers = {
    private_subnets = join(",", var.existing_private_subnets)
    public_subnets  = join(",", var.existing_public_subnets)
  }

  provisioner "local-exec" {
    command = <<-EOT
      if [ "${local.validate_private_subnet_tags}" != "true" ]; then
        echo "Private subnets are missing required tags. Required tags: ${jsonencode(local.private_subnet_tags)}"
        exit 1
      fi
      if [ "${local.validate_public_subnet_tags}" != "true" ]; then
        echo "Public subnets are missing required tags. Required tags: ${jsonencode(local.public_subnet_tags)}"
        exit 1
      fi
    EOT
  }

  depends_on = [data.aws_subnet.existing_private, data.aws_subnet.existing_public]
}