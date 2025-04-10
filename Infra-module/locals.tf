locals {
  #####################
  #      GENERAL      #
  #####################
  tags = merge(var.tags, {
    project     = "hyperspace"
    environment = "${var.environment}"
    terraform   = "true"
  })

  ##################
  #      VPC       #
  ##################
  # If availability_zone var is empty, use num_zones with default of 2
  availability_zones = length(var.availability_zones) == 0 ? slice(data.aws_availability_zones.available.names, 0, var.num_zones) : var.availability_zones
  private_subnets    = [for azs_count in local.availability_zones : cidrsubnet(var.vpc_cidr, 4, index(local.availability_zones, azs_count))]
  public_subnets     = [for azs_count in local.availability_zones : cidrsubnet(var.vpc_cidr, 4, index(local.availability_zones, azs_count) + 5)]

  ##################
  #      EKS       #
  ##################
  cluster_name = "${var.project}-${var.environment}"

  ##################
  #  IAM POLICIES  #
  ##################


  iam_policies = {
    fpga_pull = {
      name        = "${local.cluster_name}-FpgaPullAccessPolicy"
      path        = "/"
      description = "Policy for loading AFI in eks"
      policy      = data.aws_iam_policy_document.fpga_pull_access.json
    }
    ec2_tags = {
      name                     = "${local.cluster_name}-EC2TagsPolicy"
      path                     = "/"
      description              = "Policy for controling EC2 resources tags"
      policy                   = data.aws_iam_policy_document.ec2_tags_control.json
      create_cluster_wide_role = true
    }
    cluster-autoscaler = {
      name                  = "${local.cluster_name}-cluster-autoscaler"
      path                  = "/"
      description           = "Policy for cluster-autoscaler service"
      policy                = data.aws_iam_policy_document.cluster_autoscaler.json
      create_assumable_role = true
      sa_namespace          = "cluster-autoscaler"
    }
    core-dump = {
      name                  = "${local.cluster_name}-core-dump"
      path                  = "/"
      description           = "Policy for core-dump service"
      policy                = data.aws_iam_policy_document.core_dump_s3_full_access.json
      create_assumable_role = true
      sa_namespace          = "core-dump"
    }
    velero = {
      name                  = "${local.cluster_name}-velero"
      path                  = "/"
      description           = "Policy for velero service"
      policy                = data.aws_iam_policy_document.velero_s3_full_access.json
      create_assumable_role = true
      sa_namespace          = "velero"
    }
    loki = {
      name                  = "${local.cluster_name}-loki"
      path                  = "/"
      description           = "Policy for loki service"
      policy                = data.aws_iam_policy_document.loki_s3_dynamodb_full_access.json
      create_assumable_role = true
      sa_namespace          = "monitoring"
    }
    external-secrets = {
      name                  = "${local.cluster_name}-external-secrets"
      path                  = "/"
      description           = "Policy for external-secrets service"
      policy                = data.aws_iam_policy_document.secrets_manager.json
      create_assumable_role = true
      sa_namespace          = "external-secrets"
    }
    kms = {
      name        = "${local.cluster_name}-kms"
      path        = "/"
      description = "Policy for using Hyperspace's KMS key for AMI encryption"
      policy      = data.aws_iam_policy_document.kms.json
    }
  }




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


output "auth0_ingress_cidr_blocks" {
  value = local.auth0_ingress_cidr_blocks["${split("-", var.aws_region)[0]}"]
}