# variables.tf
variable "organization" {
  description = "Terraform Cloud organization name"
  type        = string
}

variable "infra_workspace_name" {
  description = "Terraform Cloud workspace name where infrastructure is defined"
  type        = string
}

# Routing
variable "domain_name" {
  description = "The main domain name to use to create sub-domains"
  type        = string
  default     = ""
}

variable "create_public_zone" {
  description = "Whether to create the public Route 53 zone"
  type        = bool
  default     = false
}

# Auto-scaling
variable "enable_cluster_autoscaler" {
  description = "should we enable and install cluster-autoscaler"
  type        = bool
  default     = true
}

# ArgoCD
variable "enable_argocd" {
  description = "should we enable and install argocd"
  type        = bool
  default     = true
}

variable "enable_ha_argocd" {
  description = "should we install argocd in ha mode"
  type        = bool
  default     = true
}

variable "dex_connectors" {
  type = string
  default     = ""
  description = "List of Dex connector configurations"
}

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
    condition     = alltrue([for instance in var.worker_instance_type : contains(["m5n.xlarge", "m5n.large"], instance)])
    error_message = "Invalid input for 'worker_instance_type'. Only the following instance type(s) are allowed: ['m5n.xlarge', 'm5n.large']."
  }
  description = "The list of allowed instance types for worker nodes."
}

variable "availability_zones" {
  type        = string
  default     = ""
  description = "List of availability zones to deploy the resources. Leave empty to automatically select based on the region and the variable num_zones."
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
  validation {
    condition     = contains(["us-east-1", "us-west-1", "eu-west-1", "eu-central-1"], var.aws_region)
    error_message = "Hyperspace currently does not support this region, valid values: [us-east-1, us-west-1, eu-west-1, eu-central-1]."
  }
  description = "This is used to define where resources are created and used"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.100.0/16"
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(\\d{1,2})$", var.vpc_cidr))
    error_message = "The VPC CIDR must be a valid CIDR block in the format X.X.X.X/XX."
  }
  description = "CIDR block for the VPC (e.g., 10.10.100.0/16) - defines the IP range for resources within the VPC."
}

variable "data_node_ami_id" {
  type        = string
  default     = ""
  description = "The AMI ID to use for the data nodes"
}
