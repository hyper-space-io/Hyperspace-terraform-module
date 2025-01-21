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
  subnet_ids      = local.vpc_module.private_subnets
  vpc_id          = local.vpc_module.vpc_id
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
      instance_types = jsondecode(var.worker_instance_type)
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
    subnets = local.vpc_module.private_subnets

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
    for subnet in slice(local.vpc_module.private_subnets, 0, length(local.availability_zones)) : {
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
      EC2TagsControl               = "${local.iam_policies["ec2_tags"].arn}"
      FpgaPull                     = "${local.iam_policies["fpga_pull"].arn}"
      KMSAccess                    = "${local.iam_policies["kms"].arn}"
    }
  }



  ##################################################################################


  #######################
  #      SECURITY       #
  #######################


  node_security_group_additional_rules = {
    ingress_auth0 = {
      description = "Allow ingress to Auth0 endpoints"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = local.auth0_ingress_cidr_blocks["${split("-", var.aws_region)[0]}"]
    }

    ingress_self_all = {
      description      = "Node to node all ports/protocols"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "ingress"
      cidr_blocks      = [local.vpc_module.vpc_cidr_block]
      ipv6_cidr_blocks = length(local.vpc_module.vpc_ipv6_cidr_block) > 0 ? [local.vpc_module.vpc_ipv6_cidr_block] : []
    }

    egress_vpc_only = {
      description      = "Node all egress within VPC"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = [local.vpc_module.vpc_cidr_block]
      ipv6_cidr_blocks = length(local.vpc_module.vpc_ipv6_cidr_block) > 0 ? [local.vpc_module.vpc_ipv6_cidr_block] : []
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
      cidr_blocks      = [local.vpc_module.vpc_cidr_block]
      ipv6_cidr_blocks = length(local.vpc_module.vpc_ipv6_cidr_block) > 0 ? [local.vpc_module.vpc_ipv6_cidr_block] : []
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

module "eks_blueprints_addons" {
  # count                               = var.create_eks ? 1 : 0
  count                               = 0
  source                              = "aws-ia/eks-blueprints-addons/aws"
  version                             = "1.16.3"
  cluster_name                        = local.cluster_name
  cluster_endpoint                    = module.eks.cluster_endpoint
  cluster_version                     = module.eks.cluster_version
  oidc_provider_arn                   = module.eks.oidc_provider_arn
  enable_aws_load_balancer_controller = module.eks.cluster_arn != ""
  aws_load_balancer_controller        = { values = [local.alb_values], wait = true }
}

# Remove non encrypted default storage class
resource "kubernetes_annotations" "default_storageclass" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = "true"

  metadata {
    name = data.kubernetes_storage_class.name.metadata[0].name
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
}

resource "kubernetes_storage_class" "ebs_sc_gp3" {
  metadata {
    name = "ebs-sc-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  parameters = {
    "csi.storage.k8s.io/fstype" = "ext4"
    encrypted                   = "true"
    type                        = "gp3"
    tagSpecification_1          = "Name={{ .PVCNamespace }}/{{ .PVCName }}"
    tagSpecification_2          = "Namespace={{ .PVCNamespace }}"
  }
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  depends_on             = [kubernetes_annotations.default_storageclass]
}

module "iam_iam-assumable-role-with-oidc" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 5.48.0"
  for_each                      = { for k, v in local.iam_policies : k => v if lookup(v, "create_assumable_role", false) == true }
  create_role                   = true
  role_name                     = each.value.name
  provider_url                  = module.eks.cluster_oidc_issuer_url
  role_policy_arns              = [local.iam_policies["${each.key}"].arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${each.value.sa_namespace}:${each.key}"]
}

module "boto3_irsa" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  for_each  = { for k, v in local.iam_policies : k => v if lookup(v, "create_cluster_wide_role", false) == true }
  role_name = each.value.name
  role_policy_arns = {
    policy = local.iam_policies["${each.key}"].arn
  }
  assume_role_condition_test = "StringLike"
  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["*:*"]
    }
  }
  depends_on = [module.eks]
}