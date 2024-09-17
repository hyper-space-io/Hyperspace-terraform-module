locals {
  # NETWORK LOCALS
  availability_zones = length(var.availability_zones) == 0 ? slice(data.aws_availability_zones.available.names, 0, var.num_zones) : var.availability_zones
  private_subnets    = [for azs_count in local.availability_zones : cidrsubnet(var.vpc_cidr, 4, index(local.availability_zones, azs_count))]
  public_subnets     = [for azs_count in local.availability_zones : cidrsubnet(var.vpc_cidr, 4, index(local.availability_zones, azs_count) + 5)]

  # EKS
  cluster_name         = "${var.project}-${var.environment}"
  enabled_cluster_logs = ["api", "audit", "controllerManager", "scheduler", "authenticator"]
  additional_self_managed_nodes_list = flatten([
    for subnet in slice(module.vpc.private_subnets, 0, var.num_zones) : [
      for pool_name, pool_values in var.additional_self_managed_node_pools : {
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
}