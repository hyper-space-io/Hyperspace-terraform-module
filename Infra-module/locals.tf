locals {
  # NETWORK LOCALS
  availability_zones = length(var.availability_zones) == 0 ? slice(data.aws_availability_zones.available.names, 0, var.num_zones) : var.availability_zones
  private_subnets    = [for azs_count in local.availability_zones : cidrsubnet(var.vpc_cidr, 4, index(local.availability_zones, azs_count))]
  public_subnets     = [for azs_count in local.availability_zones : cidrsubnet(var.vpc_cidr, 4, index(local.availability_zones, azs_count) + 5)]

  # EKS
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

  iam_policies = {
    fpga_pull = {
      name        = "${local.cluster_name}-FpgaPullAccessPolicy"
      path        = "/"
      description = "Policy for loading AFI in eks"
      policy      = data.aws_iam_policy_document.fpga_pull_access.json
    }
  }
}