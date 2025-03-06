# variables.tf
variable "organization" {
  description = "Terraform Cloud organization name"
  type        = string
  default     = "Hyperspace_project"
}

variable "infra_workspace_name" {
  description = "Terraform Cloud workspace name where infrastructure is defined"
  type        = string
  default     = "Hyperspace-test"
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
  type        = string
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
  type    = string
  default = "[m5n.xlarge]"
  validation {
    condition     = alltrue([for instance in jsondecode(var.worker_instance_type) : contains(["m5n.xlarge", "m5n.large"], instance)])
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

variable "data_node_ami_id" {
  type        = string
  default     = ""
  description = "The AMI ID to use for the data nodes"
}

variable "tags" {
  type        = string
  default     = ""
  description = "List of tags to assign to resources created in this module"
}

variable "vpc_module" {
  type        = string
  default     = ""
  description = "The VPC module to use for the resources"
}

variable "s3_buckets_names" {
  type        = string
  default     = ""
  description = "The S3 buckets to use for the resources"
}

variable "s3_buckets_arns" {
  type        = string
  default     = ""
  description = "The S3 buckets to use for the resources"
}

variable "iam_policies" {
  type        = string
  default     = ""
  description = "The IAM policies to use for the resources"
}

variable "local_iam_policies" {
  type        = string
  default     = ""
  description = "The IAM policies to use for the resources"
}