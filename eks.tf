########################
######### EKS ##########
########################

locals {
  cluster_name = "${var.project}-${var.environment}"
  additional_self_managed_node_pools = {
    # data-nodes service nodes
    eks-data-node-hyperspace = {
      name              = "eks-data-node-${local.cluster_name}"
      iam_role_name     = "data-node-${local.cluster_name}"
      enable_monitoring = true
      min_size          = 0
      max_size          = 20
      desired_size      = 0
      instance_type     = "f1.2xlarge"
      autoscaling_group_tags = {
        "k8s.io/cluster-autoscaler/node-template/taint/fpga"              = "true:NoSchedule"
        "k8s.io/cluster-autoscaler/node-template/resources/hugepages-1Gi" = "100Gi"
        "k8s.io/cluster-autoscaler/${local.cluster_name}"                 = "True"
        "k8s.io/cluster-autoscaler/enabled"                               = "True"
      }
      tags = merge(var.tags, {
        nodegroup = "fpga"
      })
      ami_id                   = "ami-0b4e17a8ddffadd10"
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
    },
    # Redis Nodes
    redis = {
      name              = "eks-redis-${local.cluster_name}"
      min_size          = 0
      max_size          = 40
      desired_size      = 0
      iam_role_name     = "redis-${local.cluster_name}"
      instance_type     = "r6g.large"
      capacity_type     = "ON_DEMAND"
      ami_type          = "BOTTLEROCKET_ARM_64"
      enable_monitoring = true
      tags = merge(var.tags, {
        nodegroup = "redis"
      })
      labels = {
        Environment = "${var.environment}"
        redis       = "true"
      }
      taints = {
        redis = {
          key    = "redis"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
      autoscaling_group_tags = {
        "k8s.io/cluster-autoscaler/node-template/resources/ephemeral-storage" = "20G"
        "k8s.io/cluster-autoscaler/node-template/taint/redis"                 = "true:NoSchedule"
        "redis"                                                               = "true"
        "k8s.io/cluster-autoscaler/enabled"                                   = "True"
        "k8s.io/cluster-autoscaler/${local.cluster_name}"                     = "True"
      }
    }
  }
  #   additional_self_managed_nodes_list = flatten([
  #     for subnet in slice(module.vpc.private_subnets, 0, var.num_zones) : [
  #       for pool_name, pool_values in local.additional_self_managed_node_pools : {
  #         key = "${var.environment}-${subnet}-${pool_name}"
  #         value = merge(
  #           pool_values,
  #           {
  #             name       = pool_name,
  #             subnet_ids = [subnet]
  #           }
  #         )
  #       }
  #     ]
  #   ])
  #   additional_self_managed_nodes = { for entry in local.additional_self_managed_nodes_list : entry.key => entry.value }
  additional_self_managed_nodes_list = flatten([
    for az in var.availability_zones : [
      for pool_name, pool_values in local.additional_self_managed_node_pools : {
        key = "${var.environment}-${az}-${pool_name}"
        value = merge(
          pool_values,
          {
            name               = pool_name,
            availability_zones = [az]
          }
        )
      }
    ]
  ])
  additional_self_managed_nodes = { for entry in local.additional_self_managed_nodes_list : entry.key => entry.value }
}





#############################################################################################################################################
module "eks" {
  ##################################################################################

  #######################
  #       GENERAL       #
  #######################

  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.24.0"
  create          = var.create_eks
  cluster_name    = local.cluster_name
  cluster_version = 1.28
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  tags            = var.tags
  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  ##################################################################################

  #######################
  # MANAGED NODE GROUPS #
  #######################

  eks_managed_node_groups = {
    eks-hyperspace-medium = {
      min_size       = 1
      max_size       = 10
      desired_size   = 1
      instance_types = ["m5n.xlarge"]
      capacity_type  = "ON_DEMAND"
      labels         = { Environment = "${var.environment}" }
      tags           = merge(var.tags, { nodegroup = "workers", Name = "${local.cluster_name}-eks-medium" })
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
    },
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

  self_managed_node_groups = local.additional_self_managed_nodes
  self_managed_node_group_defaults = {
    update_launch_template_default_version = true
    iam_role_use_name_prefix               = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      AmazonEBSCSIDriverPolicy     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
      Additional                   = "${aws_iam_policy.policies["fpga_pull"].arn}"
    }
  }

  ##################################################################################

  #######################
  #      SECURITY       #
  #######################


  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_vpc_only = {
      description      = "Node all egress within VPC"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = [var.vpc_cidr]
      ipv6_cidr_blocks = []
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
      description = "Allow all traffic from within the VPC"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = [var.vpc_cidr]
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
  version               = "~>5.44.0"
  role_name             = "${local.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true
  oidc_providers = {
    eks = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
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
  depends_on = [module.eks]
}

resource "kubernetes_storage_class" "ebs_sc_gp3" {
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = var.storage_reclaim_policy
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    "csi.storage.k8s.io/fstype" = "ext4"
    encrypted                   = "true"
    type                        = "gp3"
    tagSpecification_1          = "Name={{ .PVCNamespace }}/{{ .PVCName }}"
    tagSpecification_2          = "Namespace={{ .PVCNamespace }}"
  }
  metadata {
    name = "ebs-sc-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  depends_on = [kubernetes_annotations.default_storageclass]
}