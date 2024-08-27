locals {
  # NETWORK LOCALS
  availability_zones = length(var.availability_zones) == 0 ? slice(data.aws_availability_zones.available.names, 0, var.num_zones) : var.availability_zones
  private_subnets    = [for azs_count in local.availability_zones : cidrsubnet(var.vpc_cidr, 4, index(local.availability_zones, azs_count))]
  public_subnets     = [for azs_count in local.availability_zones : cidrsubnet(var.vpc_cidr, 4, index(local.availability_zones, azs_count) + 5)]

  # EKS
  cluster_name         = "${var.project}-${var.environment}"
  enabled_cluster_logs = ["api", "audit", "controllerManager", "scheduler", "authenticator"]
  additional_self_managed_node_pools = {
    # data-nodes service nodes
    eks-data-node-hyperspace = {
      name              = "eks-data-node-hyperspace"
      iam_role_name     = "data-node-hyperspace"
      enable_monitoring = true
      min_size          = 0
      max_size          = 20
      desired_size      = 0
      instance_type     = "f1.2xlarge"
      autoscaling_group_tags = {
        "k8s.io/cluster-autoscaler/node-template/taint/fpga"              = "true:NoSchedule"
        "k8s.io/cluster-autoscaler/node-template/resources/hugepages-1Gi" = "100Gi"
        "k8s.io/cluster-autoscaler/${var.project}-${var.environment}"     = "True"
        "k8s.io/cluster-autoscaler/enabled"                               = "True"
      }
      tags = merge(var.tags, {
        nodegroup = "fpga"
      })
      taints = {
        fpga = {
          key    = "fpga"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
      ami_id                   = "ami-050477574b83e5dcd"
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
      name              = "eks-redis-hyperspace"
      min_size          = 0
      max_size          = 40
      desired_size      = 0
      iam_role_name     = "redis-hyperspace"
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
        "k8s.io/cluster-autoscaler/${var.project}-${var.environment}"         = "True"
      }
    }
  }
  additional_self_managed_nodes_list = flatten([
    for subnet in slice(module.vpc.private_subnets, 0, var.num_zones) : [
      for pool_name, pool_values in local.additional_self_managed_node_pools : {
        key = "${var.environment}-${subnet}-${pool_name}"
        value = merge(
          pool_values,
          {
            name       = pool_name,
            subnet_ids = [subnet]
          }
        )
      }
    ]
  ])
  additional_self_managed_nodes = { for entry in local.additional_self_managed_nodes_list : entry.key => entry.value }

  eks_managed_node_groups = {
    eks-hyperspace-medium = {
      min_size       = 1
      max_size       = 10
      desired_size   = 1
      instance_types = ["m5n.xlarge"]
      capacity_type  = "ON_DEMAND"
      labels = {
        Environment = "${var.environment}"
      }
      tags = merge(var.tags, {
        nodegroup = "workers"
        Name      = "hyperspace-eks-${var.environment}-medium"
      })
      ami_type = "BOTTLEROCKET_x86_64"
    }
  }
  cluster_addons = {
    aws-ebs-csi-driver = {
      version           = "latest"
      resolve_conflicts = "OVERWRITE"
    }
    coredns = {
      version           = "latest"
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      version           = "latest"
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      version           = "latest"
      resolve_conflicts = "OVERWRITE"
    }
  }
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
      Additional                   = "${aws_iam_policy.policies["fpga_pull"].arn}"
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

  #######################
  # IAM
  #######################

  iam_policies = {
    fpga_pull = {
      name = "${local.cluster_name}-FpgaPullAccessPolicy"
      path        = "/"
      description = "Policy for loading AFI in eks"
      policy      = data.aws_iam_policy_document.fpga_pull_access.json
    }
  }
}