module "hyperspace" {
  source = "./modules/hyperspace"

  # Core Configuration
  project               = var.project
  environment          = var.environment
  hyperspace_account_id = var.hyperspace_account_id
  aws_region           = var.aws_region
  tags                 = var.tags

  # VPC Configuration
  create_vpc           = var.create_vpc
  existing_vpc_config = {
    vpc_id          = var.existing_vpc_config.vpc_id
    vpc_cidr        = var.existing_vpc_config.vpc_cidr
    private_subnets = var.existing_vpc_config.private_subnets
    public_subnets  = var.existing_vpc_config.public_subnets
  }
  availability_zones  = var.availability_zones
  enable_nat_gateway  = var.enable_nat_gateway
  single_nat_gateway  = var.single_nat_gateway
  create_vpc_flow_logs = var.create_vpc_flow_logs
  flow_logs_retention = var.flow_logs_retention
  flow_log_group_class = var.flow_log_group_class
  flow_log_file_format = var.flow_log_file_format

  # EKS Configuration
  create_eks              = var.create_eks
  worker_nodes_max        = var.worker_nodes_max
  worker_instance_type    = var.worker_instance_type
  enable_cluster_autoscaler = var.enable_cluster_autoscaler
  eks_additional_admin_roles = var.eks_additional_admin_roles

  # DNS Configuration
  domain_name        = var.domain_name
  create_public_zone = var.create_public_zone

  # S3 Configuration
  s3_buckets_names = var.s3_buckets_names
  s3_buckets_arns  = var.s3_buckets_arns

  # IAM Configuration
  iam_policies       = var.iam_policies
  local_iam_policies = var.local_iam_policies

  # Monitoring Configuration
  prometheus_endpoint_config = var.prometheus_endpoint_config
  grafana_privatelink_config = var.grafana_privatelink_config

  # ArgoCD Configuration
  argocd_config = var.argocd_config

  # Terraform Cloud Configuration
  tfe_organization = var.tfe_organization
} 