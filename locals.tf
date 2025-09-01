locals {
  # General
  tags = merge(var.tags, {
    Project     = "hyperspace"
    Environment = var.environment
    Terraform   = "true"
  })

  ################
  ## Hyperspace ##
  ################
  hyperspace_helm_region = "eu-west-1"

  ###############
  ### Ingress ###
  ###############
  internal_ingress_class_name = "nginx-internal"

  ###############
  ##### ALB #####
  ###############
  alb_values = <<EOT
  vpcId: ${local.vpc_id}
  region: ${var.aws_region}
  EOT

  ##################
  ##### KMS ########
  ##################
  hyperspace_ami_key_alias = "arn:aws:kms:${var.aws_region}:${var.hyperspace_account_id}:alias/HYPERSPACE_AMI_KEY"

  ##################
  ##### VPC ########
  ##################
  # Determine if we need to create a new VPC or use existing one
  create_vpc = var.existing_vpc_id == null ? true : false

  # Store existing VPC details when using an existing VPC
  existing_vpc = {
    id              = local.create_vpc ? null : data.aws_vpc.existing[0].id
    cidr_block      = local.create_vpc ? null : data.aws_vpc.existing[0].cidr_block
    private_subnets = local.create_vpc ? [] : var.existing_private_subnets
  }

  # Get availability zones either from existing subnets or create new ones
  availability_zones = local.create_vpc ? (length(var.availability_zones) == 0 ? slice(data.aws_availability_zones.available.names, 0, var.num_zones) : var.availability_zones) : (length(data.aws_subnet.existing_private) > 0 ? [for subnet in data.aws_subnet.existing_private : subnet.availability_zone] : [])

  # Used to calculate the subnets. These are only used when creating a new VPC
  private_subnets = local.create_vpc ? [for azs_count in local.availability_zones : cidrsubnet(var.vpc_cidr, 4, index(local.availability_zones, azs_count))] : []
  public_subnets  = local.create_vpc ? [for azs_count in local.availability_zones : cidrsubnet(var.vpc_cidr, 4, index(local.availability_zones, azs_count) + 5)] : []

  # Use VPC module outputs for new VPC, or existing values from input variables for existing VPC
  private_subnets_ids = local.create_vpc ? module.vpc[0].private_subnets : var.existing_private_subnets
  vpc_id              = local.create_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
  vpc_cidr_block      = local.create_vpc ? module.vpc[0].vpc_cidr_block : local.existing_vpc.cidr_block

  # Required tags for subnets
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "Type"                            = "private"
    "karpenter.sh/discovery"          = "${var.project}-${var.environment}"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "Type"                   = "public"
  }

  ###################
  ##### Route53 #####
  ###################
  # Zone creation flags
  create_private_zone = local.internal_domain_name != null && var.existing_private_zone_id == null
  create_public_zone  = local.public_domain_name != null && var.existing_public_zone_id == null

  # external LB creation
  create_external_lb = local.create_public_zone || var.domain_validation_zone_id != null

  # Zone IDs - use existing zones when provided, otherwise use newly created zones
  private_zone_id = var.existing_private_zone_id != null ? var.existing_private_zone_id : (local.create_private_zone ? module.internal_zone[0].route53_zone_zone_id["internal"] : null)
  public_zone_id  = var.existing_public_zone_id != null ? var.existing_public_zone_id : (local.create_public_zone ? module.external_zone[0].route53_zone_zone_id["external"] : null)

  # ACM validation priority:
  # 1. domain_validation_zone_id (if provided)
  # 2. existing_public_zone_id (if provided)
  # 3. null (manual validation)
  validation_zone_id = var.domain_validation_zone_id != null ? var.domain_validation_zone_id : (
    var.existing_public_zone_id != null ? var.existing_public_zone_id : null
  )

  #################
  ##### EKS #######
  #################
  merged_map_roles = distinct(concat(
    var.enable_karpenter ? [
      {
        rolearn  = module.karpenter[0].iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes",
        ]
      },
      {
        rolearn  = module.karpenter[0].node_iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes",
        ]
      }
    ] : [],

    var.map_roles,
  ))

  fargate_profiles = merge(
    # Only add Karpenter Fargate profile if Karpenter is enabled and Fargate is enabled for it
    var.enable_karpenter && try(var.karpenter_controller_config.fargate_enabled, false) ? {
      karpenter = {
        selectors = [
          { namespace = "karpenter" }
        ]
        subnet_ids = slice(local.private_subnets_ids, 0, var.num_zones)
      }
    } : {},
    var.fargate_profiles
  )
  cluster_name = "${var.project}-${var.environment}"
  
  fpga_node_groups_defaults = {
    enable_monitoring        = true
    min_size                 = 0
    max_size                 = 20
    desired_size             = 0
    ami_id                   = data.aws_ami.fpga.id
    bootstrap_extra_args     = "--kubelet-extra-args '--node-labels=hyperspace.io/type=fpga --register-with-taints=fpga=true:NoSchedule'"
    post_bootstrap_user_data = <<-EOT
      #!/bin/bash -e
      mkdir /data
      vgcreate "data" /dev/nvme0n1
      COUNT=1
      lvcreate -l 100%VG -i $COUNT -n data data
      mkfs.xfs /dev/data/data
      mount /dev/mapper/data-data /data
      echo "/dev/mapper/data-data /data xfs defaults,noatime 1 1" >> /etc/fstab
      mkdir /data/private/
      EOT
    tags                     = merge(local.tags, { nodegroup = "fpga" })
    
    block_device_mappings = {
      root = {
        device_name = "/dev/xvda"
        ebs = {
          encrypted   = true
          volume_size = 200
          volume_type = "gp3"
          iops        = 3000
          throughput  = 125
        }
      }
    }
  }
  additional_self_managed_node_pools = {
    # data-nodes service nodes
    for instance_type in ["f1.2xlarge", "f1.4xlarge", "f2.6xlarge"] :
    "eks-data-node-${instance_type}" => merge(
      local.fpga_node_groups_defaults,
      {
        name          = "eks-data-node-${instance_type}"
        iam_role_name = "data-node-${instance_type}"
        instance_type = instance_type
      }
    )
  }
  ###########################
  ### Grafana Privatelink ###
  ###########################
  grafana_privatelink_enabled = var.create_eks && var.grafana_privatelink_config.enabled

  # Default values for Grafana Privatelink configuration
  grafana_endpoint_default_aws_regions        = ["eu-central-1", "us-east-1"]
  grafana_endpoint_default_allowed_principals = ["arn:aws:iam::${var.hyperspace_account_id}:root"]

  grafana_privatelink_allowed_principals = distinct(concat(
    var.grafana_privatelink_config.endpoint_allowed_principals,
    local.grafana_endpoint_default_allowed_principals
  ))

  grafana_privatelink_supported_regions = distinct(concat(
    [var.aws_region],
    var.grafana_privatelink_config.additional_aws_regions,
    local.grafana_endpoint_default_aws_regions
  ))

  ###########################
  ####### Prometheus ########
  ###########################
  prometheus_endpoint_config       = var.prometheus_endpoint_config
  prometheus_endpoint_enabled      = var.create_eks && var.prometheus_endpoint_config.enabled
  prometheus_remote_write_endpoint = ""

  ###########################
  ######### ArgoCD  #########
  ###########################
  argocd_config  = var.argocd_config
  argocd_enabled = var.create_eks && var.argocd_config.enabled

  ###########################
  ### ArgoCD Privatelink ####
  ###########################
  argocd_privatelink_enabled = local.argocd_enabled && try(local.argocd_config.privatelink.enabled, false)

  # Default values for Privatelink configuration
  argocd_endpoint_default_aws_regions        = ["eu-central-1", "us-east-1"]
  argocd_endpoint_default_allowed_principals = ["arn:aws:iam::${var.hyperspace_account_id}:root"]

  # Combine default and custom allowed principals
  argocd_privatelink_allowed_principals = distinct(concat(
    try(local.argocd_config.privatelink.endpoint_allowed_principals, []),
    local.argocd_endpoint_default_allowed_principals
  ))
  argocd_privatelink_supported_regions = distinct(concat(
    [var.aws_region],
    try(local.argocd_config.privatelink.additional_aws_regions, []),
    local.argocd_endpoint_default_aws_regions
  ))

  # ArgoCD ConfigMap values
  argocd_configmap_values = merge({
    "exec.enabled"           = "false"
    "timeout.reconciliation" = "5s"
    "dex.config" = yamlencode({
      connectors = local.dex_connectors
    })
    }, local.argocd_privatelink_enabled ? {
    "accounts.hyperspace" = "login"
  } : {})

  ###################
  ### ArgoCD VCS ####
  ###################

  github_vcs_enabled     = local.argocd_enabled && try(local.argocd_config.vcs.github.enabled, false)
  github_vcs_app_enabled = local.github_vcs_enabled && try(local.argocd_config.vcs.github.github_app_enabled, false)

  gitlab_vcs_enabled       = local.argocd_enabled && try(local.argocd_config.vcs.gitlab.enabled, false)
  gitlab_vcs_oauth_enabled = local.gitlab_vcs_enabled && try(local.argocd_config.vcs.gitlab.oauth_enabled, false)

  # VCS connector configuration for Dex
  dex_connectors = concat(
    local.github_vcs_app_enabled ? [{
      type = "github"
      id   = "github"
      name = "GitHub"
      config = {
        clientID     = try(jsondecode(data.aws_secretsmanager_secret_version.argocd_github_app[0].secret_string).client_id, null)
        clientSecret = try(jsondecode(data.aws_secretsmanager_secret_version.argocd_github_app[0].secret_string).client_secret, null)
        orgs         = [{ name = local.argocd_config.vcs.organization }]
      }
    }] : [],
    local.gitlab_vcs_oauth_enabled ? [{
      type = "gitlab"
      id   = "gitlab"
      name = "GitLab"
      config = {
        baseURL      = "https://gitlab.com"
        clientID     = try(jsondecode(data.aws_secretsmanager_secret_version.argocd_gitlab_oauth[0].secret_string).application_id, null)
        clientSecret = try(jsondecode(data.aws_secretsmanager_secret_version.argocd_gitlab_oauth[0].secret_string).secret, null)
        orgs         = [{ name = local.argocd_config.vcs.organization }]
      }
    }] : []
  )

  # ArgoCD credential templates
  argocd_credential_templates = merge(
    local.github_vcs_app_enabled ? {
      "github-creds" = {
        url                     = "https://github.com/${local.argocd_config.vcs.organization}/${local.argocd_config.vcs.repository}"
        githubAppID             = try(jsondecode(data.aws_secretsmanager_secret_version.argocd_github_app[0].secret_string).github_app_id, null)
        githubAppInstallationID = try(jsondecode(data.aws_secretsmanager_secret_version.argocd_github_app[0].secret_string).github_installation_id, null)
        githubAppPrivateKey     = try(data.aws_secretsmanager_secret_version.argocd_github_app_private_key[0].secret_string, null)
      }
    } : {},
    local.gitlab_vcs_enabled ? {
      "gitlab-creds" = {
        url      = "https://gitlab.com/${local.argocd_config.vcs.organization}/${local.argocd_config.vcs.repository}.git"
        username = try(jsondecode(data.aws_secretsmanager_secret_version.argocd_gitlab_credentials[0].secret_string).username, null)
        password = try(jsondecode(data.aws_secretsmanager_secret_version.argocd_gitlab_credentials[0].secret_string).password, null)
      }
    } : {}
  )

  # Default ArgoCD RBAC policy rules for localusers
  argocd_rbac_policy_default = "role:readonly"

  # Base role definitions
  base_rbac_rules = [
    "p, role:org-admin, applications, *, */*, allow",
    "p, role:org-admin, clusters, get, *, allow",
    "p, role:org-admin, repositories, get, *, allow",
    "p, role:org-admin, repositories, create, *, allow",
    "p, role:org-admin, repositories, update, *, allow",
    "p, role:org-admin, repositories, delete, *, allow",
    "p, role:org-admin, projects, get, *, allow",
    "p, role:org-admin, projects, create, *, allow",
    "p, role:org-admin, projects, update, *, allow",
    "p, role:org-admin, projects, delete, *, allow",
    "p, role:org-admin, logs, get, *, allow",
    "p, role:org-admin, exec, create, */*, allow"
  ]

  # SSO access rules
  sso_rbac_rules = try(local.argocd_config.rbac.sso_admin_group != "", false) ? [
    "g, ${try(local.argocd_config.vcs.organization, "")}:${try(local.argocd_config.rbac.sso_admin_group, "")}, role:org-admin",
    "g, ${try(local.argocd_config.vcs.organization, "")}:*, role:org-admin"
    ] : [
    "g, ${try(local.argocd_config.vcs.organization, "")}:*, role:org-admin",
    "g, ${try(local.argocd_config.vcs.organization, "")}, role:org-admin"
  ]

  # User rules
  user_rbac_rules = try(local.argocd_config.rbac.sso_admin_group != "", false) ? try(local.argocd_config.rbac.users_rbac_rules, []) : []

  # Additional rules
  additional_rbac_rules = try(local.argocd_config.rbac.users_additional_rules, [])

  # Combined rules
  argocd_rbac_policy_rules = distinct(concat(
    local.base_rbac_rules,
    local.sso_rbac_rules,
    local.user_rbac_rules,
    local.additional_rbac_rules
  ))

  #################
  ##### Auth0 #####
  #################
  auth0_ingress_cidr_blocks = {
    us = [
      "174.129.105.183/32",
      "18.116.79.126/32",
      "18.117.64.128/32",
      "18.191.46.63/32",
      "18.218.26.94/32",
      "18.232.225.224/32",
      "18.233.90.226/32",
      "3.131.238.180/32",
      "3.131.55.63/32",
      "3.132.201.78/32",
      "3.133.18.220/32",
      "3.134.176.17/32",
      "3.19.44.88/32",
      "3.20.244.231/32",
      "3.21.254.195/32",
      "3.211.189.167/32",
      "34.211.191.214/32",
      "34.233.19.82/32",
      "34.233.190.223/32",
      "35.160.3.103/32",
      "35.162.47.8/32",
      "35.166.202.113/32",
      "35.167.74.121/32",
      "35.171.156.124/32",
      "35.82.131.220/32",
      "44.205.93.104/32",
      "44.218.235.21/32",
      "44.219.52.110/32",
      "52.12.243.90/32",
      "52.2.61.131/32",
      "52.204.128.250/32",
      "52.206.34.127/32",
      "52.43.255.209/32",
      "52.88.192.232/32",
      "52.89.116.72/32",
      "54.145.227.59/32",
      "54.157.101.160/32",
      "54.200.12.78/32",
      "54.209.32.202/32",
      "54.245.16.146/32",
      "54.68.157.8/32",
      "54.69.107.228/32"
    ],
    eu = [
      "18.197.9.11/32",
      "18.198.229.148/32",
      "3.125.185.137/32",
      "3.65.249.224/32",
      "3.67.233.131/32",
      "3.68.125.137/32",
      "3.72.27.152/32",
      "3.74.90.247/32",
      "34.246.118.27/32",
      "35.157.198.116/32",
      "35.157.221.52/32",
      "52.17.111.199/32",
      "52.19.3.147/32",
      "52.208.95.174/32",
      "52.210.121.45/32",
      "52.210.122.50/32",
      "52.28.184.187/32",
      "52.30.153.34/32",
      "52.57.230.214/32",
      "54.228.204.106/32",
      "54.228.86.224/32",
      "54.73.137.216/32",
      "54.75.208.179/32",
      "54.76.184.103/32"
    ]
  }
}