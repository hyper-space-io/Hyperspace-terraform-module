###############################
########## Global #############
###############################

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

variable "hyperspace_account_id" {
  description = "The account ID of the hyperspace account"
  type        = string
}

variable "tfe_organization" {
  description = "Terraform Cloud organization name"
  type        = string
}

variable "infra_workspace_name" {
  description = "Terraform Cloud workspace name where infrastructure is defined"
  type        = string
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

variable "tags" {
  type        = string
  default     = ""
  description = "List of tags to assign to resources created in this module"
}

###############################
######### Route53 #############
###############################

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

###############################
############ EKS ##############
###############################

variable "create_eks" {
  type        = bool
  default     = true
  description = "Should we create the eks cluster?"
}

variable "enable_cluster_autoscaler" {
  description = "should we enable and install cluster-autoscaler"
  type        = bool
  default     = true
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
  default = "m5n.xlarge"
  validation {
    condition     = alltrue([for instance in jsondecode(var.worker_instance_type) : contains(["m5n.xlarge", "m5n.large", "m5d.xlarge", "m5d.large"], instance)])
    error_message = "Invalid input for 'worker_instance_type'. Only the following instance type(s) are allowed: ['m5n.xlarge', 'm5n.large', 'm5d.xlarge', 'm5d.large']."
  }
  description = "The list of allowed instance types for worker nodes."
}

###############################
########## ArgoCD #############
###############################

variable "argocd_config" {
  description = "ArgoCD configuration including VCS and RBAC settings"
  type        = string
  default     = "{}"
}

###############################
########### VPC ###############
###############################

variable "vpc_module" {
  type        = string
  default     = ""
  description = "The VPC module to use for the resources"
}

variable "availability_zones" {
  type        = string
  default     = ""
  description = "List of availability zones to deploy the resources. Leave empty to automatically select based on the region and the variable num_zones."
}

###############################
############ S3 ###############
###############################

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

###############################
############ IAM ##############
###############################

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

################################
###### ArgoCD Privatelink ######
################################

variable "argocd_endpoint_additional_aws_regions" {
  type        = string
  description = "The additional aws regions to enable for the argocd vpc endpoint"
}

variable "argocd_endpoint_allowed_principals" {
  type        = string
  default     = ""
  description = "The allowed principals for the argocd vpc endpoint"
}

################################
#### Prometheus Privatelink ####
################################

variable "prometheus_privatelink_config" {
  type        = string
  default     = {}
  description = "The prometheus privatelink config"
}