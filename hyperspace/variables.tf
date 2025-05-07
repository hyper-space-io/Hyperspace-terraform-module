########################
# GENERAL

########################

variable "hyperspace_account_id" {
  type        = string
  description = "Hyperspace Account ID - this is used to access cross-account resources"
}

variable "project" {
  type        = string
  default     = "hyperspace"
  description = "Name of the project - this is used to generate names for resources"
}

variable "environment" {
  type        = string
  default     = "development"
  description = "The environment we are creating - used to generate names for resource"
}

variable "tags" {
  type        = map(any)
  default     = {}
  description = "List of tags to assign to resources created in this module"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
  validation {
    condition     = contains(["us-east-1", "us-west-1", "eu-west-1", "eu-central-1", "eu-west-2"], var.aws_region)
    error_message = "Hyperspace currently does not support this region, valid values: [us-east-1, us-west-1, eu-west-1, eu-central-1, eu-west-2]."
  }
  description = "This is used to define where resources are created and used"
}

########################
# VPC
########################

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(\\d{1,2})$", var.vpc_cidr))
    error_message = "The VPC CIDR must be a valid CIDR block in the format X.X.X.X/XX."
  }
  description = "CIDR block for the VPC (e.g., 10.10.0.0/16) - defines the IP range for resources within the VPC."
}

variable "num_zones" {
  type    = number
  default = 2
  validation {
    condition     = var.num_zones <= length(data.aws_availability_zones.available.names)
    error_message = "The number of zones specified (num_zones) exceeds the number of available availability zones in the selected region. The number of available AZ's is ${length(data.aws_availability_zones.available.names)}"
  }
  description = "How many zones should we utilize for the eks nodes"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "List of availability zones to deploy the resources. Leave empty to automatically select based on the region and the variable num_zones."
}

variable "enable_nat_gateway" {
  type        = bool
  default     = true
  description = "Dictates if nat gateway is enabled or not"
}

variable "single_nat_gateway" {
  type        = bool
  default     = false
  description = "Whether to create a single NAT gateway (true) or one per availability zone (false)."
}

variable "create_vpc_flow_logs" {
  type        = bool
  default     = false
  description = "Whether we create vpc flow logs or not"
}

variable "flow_logs_retention" {
  type        = number
  default     = 14
  description = "vpc flow logs retention in days"
}

variable "flow_log_group_class" {
  type        = string
  default     = "STANDARD"
  description = "VPC flow logs log group class in CloudWatch. Leave empty for default or provide a specific class."
}

variable "flow_log_file_format" {
  type    = string
  default = "parquet"
  validation {
    condition     = contains(["parquet", "plain-text", "json"], var.flow_log_file_format)
    error_message = "Flow log file format must be one of 'parquet', 'plain-text', or 'json'."
  }
  description = "The format for the flow log."
}

variable "extra_peering_connections" {
  description = "Map of extra VPC peering connections"
  type = map(object({
    peer_vpc_id     = string
    peer_cidr       = string
    peer_account_id = string
    peer_region     = string
  }))
  default = {}
}

########################
# EKS
########################

variable "create_eks" {
  type        = bool
  default     = true
  description = "Should we create the eks cluster?"
}

variable "worker_nodes_max" {
  type    = number
  default = 10
  validation {
    condition     = var.worker_nodes_max > 0
    error_message = "Invalid input for 'worker_nodes_max'. The value must be a number greater than 0."
  }
  description = "The maximum amount of worker nodes you can allow"
}

variable "worker_instance_type" {
  type    = list(string)
  default = ["m5n.xlarge"]
  validation {
    condition     = alltrue([for instance in var.worker_instance_type : contains(["m5n.xlarge", "m5n.large", "m6i.large", "m6i.xlarge"], instance)])
    error_message = "Invalid input for 'worker_instance_type'. Only the following instance type(s) are allowed: ['m5n.xlarge', 'm5n.large', 'm6i.large', 'm6i.xlarge']."
  }
  description = "The list of allowed instance types for worker nodes."
}

variable "node_security_group_additional_rules" {
  description = "Additional security group rules to add to the node security group"
  type        = any
  default     = {}
}

variable "cluster_security_group_additional_rules" {
  description = "Additional security group rules to add to the cluster security group"
  type        = any
  default     = {}
}

variable "eks_access_entries" {
  description = "Map of access entries to add to the EKS cluster"
  type = map(object({
    kubernetes_groups = list(string)
    principal_arn     = string
    type              = string
  }))
  default = {}
}

# Auto-scaling
variable "enable_cluster_autoscaler" {
  description = "should we enable and install cluster-autoscaler"
  type        = bool
  default     = true
}

# APP MODULE
variable "create_public_zone" {
  description = "Whether to create the public Route 53 zone"
  type        = bool
  default     = false
}

variable "enable_ha_argocd" {
  description = "should we install argocd in ha mode"
  type        = bool
  default     = false
}

variable "enable_argocd_private_link" {
  description = "should we create private link for argocd"
  type        = bool
  default     = false
}

variable "dex_connectors" {
  type        = list(any)
  default     = []
  description = "List of Dex connector configurations"
}

variable "domain_name" {
  description = "The main domain name to use to create sub-domains"
  type        = string
  default     = ""
}

# Agent

variable "existing_agent_pool_name" {
  description = "Name of existing agent pool to use. If empty, a new agent pool will be created"
  type        = string
  default     = ""
}

variable "extra_routes" {
  description = "Map of extra routes to add to the private route tables"
  type        = map(any)
  default     = {}
}

# ArgoCD

variable "argocd_rbac_policy_default" {
  description = "default role for argocd"
  type        = string
  default     = "role:readonly"
}

variable "argocd_rbac_policy_rules" {
  description = "Rules for argocd rbac"
  type        = list(string)
  default     = []
}

variable "enable_argocd" {
  description = "should we enable and install argocd"
  type        = bool
  default     = true
}


variable "create_prometheus_private_link" {
  description = "should we create private link for prometheus"
  type        = bool
  default     = true
}

variable "prometheus_endpoint_additional_cidr_blocks" {
  type        = string
  default     = ""
  description = "The CIDR blocks to allow access to the prometheus vpc endpoint"
}

variable "prometheus_endpoint_service_name" {
  type        = string
  default     = ""
  description = "The service name to use for the prometheus vpc endpoint"
}

variable "prometheus_endpoint_service_region" {
  type        = string
  default     = ""
  description = "The region the prometheus vpc endpoint will connect to"
}