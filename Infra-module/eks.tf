########################
#         EKS          #
########################


module "eks" {


  ##################################################################################


  #######################
  #       GENERAL       #
  #######################

  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.8.5"
  create          = var.create_eks
  cluster_name    = local.cluster_name
  cluster_version = "1.31"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  tags            = local.tags

  cluster_addons = {
    aws-ebs-csi-driver = { most_recent = true }
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    vpc-cni            = { most_recent = true }
  }


  ##################################################################################


  #######################
  # MANAGED NODE GROUPS #
  #######################


  eks_managed_node_groups = {
    eks-hyperspace-medium = {
      min_size       = 1
      max_size       = var.worker_nodes_max
      desired_size   = 1
      instance_types = var.worker_instance_type
      capacity_type  = "ON_DEMAND"
      labels         = { Environment = "${var.environment}" }
      tags           = merge(local.tags, { nodegroup = "workers", Name = "${local.cluster_name}-eks-medium" })
      ami_type       = "BOTTLEROCKET_x86_64"

      block_device_mappings = {
        xvdb = {
          device_name = "/dev/xvdb"
          ebs = {
            volume_size           = 80
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }

  eks_managed_node_group_defaults = {
    update_launch_template_default_version = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      AmazonEBSCSIDriverPolicy     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }
    subnets = module.vpc.private_subnets

    tags = {
      "k8s.io/cluster-autoscaler/enabled"               = "True"
      "k8s.io/cluster-autoscaler/${local.cluster_name}" = "True"
      "Name"                                            = "${local.cluster_name}"
    }
  }


  ##################################################################################


  ############################
  # SELF MANAGED NODE GROUPS #
  ############################

  # Sperating the self managed nodegroups to az's ( 1 AZ : 1 ASG )
  self_managed_node_groups = merge([
    for subnet in slice(module.vpc.private_subnets, 0, length(local.availability_zones)) : {
      for pool_name, pool_values in local.additional_self_managed_node_pools :
      "${var.environment}-${subnet}-${pool_name}" => merge(
        pool_values,
        {
          name       = pool_name,
          subnet_ids = [subnet]
        }
      )
    }
  ]...)

  self_managed_node_group_defaults = {
    update_launch_template_default_version = true
    iam_role_use_name_prefix               = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      AmazonEBSCSIDriverPolicy     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      EC2TagsControl               = "${aws_iam_policy.policies["ec2_tags"].arn}"
      FpgaPull                     = "${aws_iam_policy.policies["fpga_pull"].arn}"
      KMSAccess                    = "${aws_iam_policy.policies["kms"].arn}"
    }
  }


  ##################################################################################


  #######################
  #      SECURITY       #
  #######################


  node_security_group_additional_rules = {
      egress_auth0 = {
      description = "Allow egress to Auth0 endpoints"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "egress"
      cidr_blocks = [
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
      ]
    }

    ingress_self_all = {
      description      = "Node to node all ports/protocols"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "ingress"
      cidr_blocks      = [var.vpc_cidr]
      ipv6_cidr_blocks = length(module.vpc.vpc_ipv6_cidr_block) > 0 ? [module.vpc.vpc_ipv6_cidr_block] : []
    }

    egress_vpc_only = {
      description      = "Node all egress within VPC"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = [var.vpc_cidr]
      ipv6_cidr_blocks = length(module.vpc.vpc_ipv6_cidr_block) > 0 ? [module.vpc.vpc_ipv6_cidr_block] : []
    }

    cluster_nodes_incoming = {
      description                   = "Allow traffic from cluster to node on ports 1025-65535"
      protocol                      = "tcp"
      from_port                     = 1025
      to_port                       = 65535
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  cluster_security_group_additional_rules = {
    recieve_traffic_from_vpc = {
      description      = "Allow all traffic from within the VPC"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "ingress"
      cidr_blocks      = [var.vpc_cidr]
      ipv6_cidr_blocks = length(module.vpc.vpc_ipv6_cidr_block) > 0 ? [module.vpc.vpc_ipv6_cidr_block] : []
    }
  }

  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = "true"
  cluster_endpoint_private_access          = "true"
  cluster_endpoint_public_access           = "false"
  create_kms_key                           = true
  kms_key_description                      = "EKS Secret Encryption Key"


  ##################################################################################


  #######################
  #      LOGGING        #
  #######################


  cloudwatch_log_group_retention_in_days = "7"
  cluster_enabled_log_types              = ["api", "audit", "controllerManager", "scheduler", "authenticator"]


  ##################################################################################


  #######################
  #    DEPENDENCIES     #
  #######################

  depends_on = [module.vpc]

}


#############################################################################################################################################


# EBS CSI Driver IRSA 
module "irsa-ebs-csi" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "~>5.48.0"
  role_name             = "${local.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    eks = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}


#############################################################################################################################################


data "aws_kms_key" "by_alias" {
  key_id = "arn:aws:kms:${var.aws_region}:418316469434:alias/AMI_CROSS_ACCOUNT"
}

# Create the KMS grant
resource "aws_kms_grant" "asg_grant" {
  name              = "asg-cross-account-grant"
  key_id            = data.aws_kms_key.by_alias.arn
  grantee_principal = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
  operations = [
    "Encrypt",
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "DescribeKey",
  ]
}