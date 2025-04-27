########################
####### GENERAL ########
########################

variable "project" {
  type        = string
  default     = "hyperspace"
  description = "Name of the project - this is used to generate names for resources"
}

variable "hyperspace_account_id" {
  type        = string
  description = "The account ID of the hyperspace account"
}

variable "tfe_organization" {
  description = "Terraform Cloud organization name"
  type        = string
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

variable "hyperspace_aws_region" {
  type        = string
  default     = "us-east-1"
  description = "The region of the hyperspace account"
}

variable "tfc_agent_token" {
  description = "Terraform Cloud agent token"
  type        = string
  sensitive   = true
}

########################
######### VPC ##########
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

########################
######### EKS ##########
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
    condition     = alltrue([for instance in var.worker_instance_type : contains(["m5n.xlarge", "m5n.large", "m5d.xlarge", "m5d.large"], instance)])
    error_message = "Invalid input for 'worker_instance_type'. Only the following instance type(s) are allowed: ['m5n.xlarge', 'm5n.large', 'm5d.xlarge', 'm5d.large']."
  }
  description = "The list of allowed instance types for worker nodes."
}

########################
#### Auto-scaling ######
########################

variable "enable_cluster_autoscaler" {
  description = "should we enable and install cluster-autoscaler"
  type        = bool
  default     = true
}

########################
###### APP MODULE ######
########################

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

variable "domain_name" {
  description = "The main domain name to use to create sub-domains"
  type        = string
  default     = ""
}

variable "existing_agent_pool_name" {
  description = "The name of the existing agent pool to use"
  type        = string
  default     = ""
}

variable "argocd_vcs_configuration" {
  type = object({
    organization = string
    branch       = string
    github = optional(object({
      enabled                 = optional(bool)
      app_secret_name         = optional(string)
      private_key_secret_name = optional(string)
    }))
    gitlab = optional(object({
      enabled = optional(bool)
      ssh_key = optional(object({
        enabled     = bool
        secret_name = optional(string)
      }))
      access_token = optional(object({
        enabled     = bool
        secret_name = optional(string)
      }))
    }))
  })
  default = {
    organization = ""
    branch       = "master"
    github = {
      enabled                 = false
      app_secret_name         = "argocd/githubapp"
      private_key_secret_name = "argocd/github-private-key"
    }
    gitlab = {
      enabled = false
      ssh_key = {
        enabled = false
      }
      access_token = {
        enabled = false
      }
    }
  }
  description = "Configuration for VCS authentication in ArgoCD"
}

################################
###### ArgoCD Privatelink ######
################################

variable "argocd_endpoint_additional_aws_regions" {
  type        = list(string)
  default     = ["eu-central-1"]
  description = "The additional aws regions to enable for the argocd vpc endpoint"
}

variable "argocd_endpoint_allowed_principals" {
  type        = list(string)
  default     = []
  description = "The allowed principals for the argocd vpc endpoint"
}

################################
#### Prometheus Privatelink ####
################################

variable "prometheus_endpoint_service_name" {
  type        = string
  description = "The service name the vpc endpoint will connect to"
}

variable "prometheus_endpoint_additional_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "The CIDR blocks to allow access to the prometheus vpc endpoint"
}

variable "prometheus_endpoint_service_region" {
  type        = string
  default     = "us-east-1"
  description = "The region the prometheus vpc endpoint will connect to"
}