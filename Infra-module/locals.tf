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
  default_node_pool_tags = {
    "k8s.io/cluster-autoscaler/enabled"               = "True"
    "k8s.io/cluster-autoscaler/${local.cluster_name}" = "True"
  }

  additional_self_managed_node_pools = {
    # data-nodes service nodes
    eks-data-node-hyperspace = {
      name                     = "eks-data-node-${local.cluster_name}"
      iam_role_name            = "data-node-${local.cluster_name}"
      enable_monitoring        = true
      min_size                 = 0
      max_size                 = 20
      desired_size             = 0
      instance_type            = "f1.2xlarge"
      ami_id                   = "${data.aws_ami.fpga.image_id}"
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
      autoscaling_group_tags = merge(local.default_node_pool_tags, {
        "k8s.io/cluster-autoscaler/node-template/taint/fpga"              = "true:NoSchedule"
        "k8s.io/cluster-autoscaler/node-template/resources/hugepages-1Gi" = "100Gi"
      })
      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            encrypted   = true
            volume_size = 200
            volume_type = "gp3"
            iops       = 3000
            throughput = 125
          }
        }
      }
    }
  }

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
      name        = "${local.cluster_name}-EC2TagsPolicy"
      path        = "/"
      description = "Policy for controling EC2 resources tags"
      policy      = data.aws_iam_policy_document.ec2_tags_control.json
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
      name                  = "${local.cluster_name}-kms"
      path                  = "/"
      description           = "Policy for using Hyperspace's KMS key for AMI encryption"
      policy                = data.aws_iam_policy_document.kms.json
    }
  }
}