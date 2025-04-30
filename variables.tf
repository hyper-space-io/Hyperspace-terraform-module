###############################
########## Global #############
###############################

variable "project" {
  type        = string
  description = "Name of the project"
  default     = "hyperspace"
}

variable "environment" {
  type        = string
  description = "Environment Name"
  default     = "development"
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
  type        = map(string)
  description = "A map of tags to add to all resources"
  default     = {}
}

########################
#### Hyperspace ########
########################

variable "hyperspace_account_id" {
  type        = string
  description = "The account ID of the hyperspace account, used to pull resources from Hyperspace like AMIs"
}

###############################
########### VPC ###############
###############################

variable "create_vpc" {
  description = "Controls if VPC should be created"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "List of availability zones to deploy the resources. Leave empty to automatically select based on the region and the variable num_zones."
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

variable "enable_nat_gateway" {
  type        = bool
  description = "Enable NAT Gateway"
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use single NAT Gateway OR one per AZ"
  default     = false
}

variable "existing_vpc_config" {
  description = "Configuration for using an existing VPC"
  type = object({
    vpc_id            = string
    vpc_cidr          = string
    private_subnets   = list(string)
    public_subnets    = list(string)
  })
  default = {
    vpc_id          = null
    vpc_cidr        = null
    private_subnets = []
    public_subnets  = []
  }
}

variable "create_vpc_flow_logs" {
  type        = bool
  description = "Enable VPC flow logs"
  default     = false
}

variable "flow_logs_retention" {
  type        = number
  description = "Flow logs retention in days"
  default     = 14
}

variable "flow_log_group_class" {
  type        = string
  description = "Flow logs log group class in CloudWatch"
  default     = "STANDARD"
}

variable "flow_log_file_format" {
  type        = string
  description = "Flow logs file format"
  default     = "parquet"
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
  description = "The instance type for the EKS worker nodes"
  type        = list(string)
  default     = ["m5n.xlarge"]

  validation {
    condition     = alltrue([for instance in var.worker_instance_type : contains(["m5n.xlarge", "m5n.large", "m5d.xlarge", "m5d.large"], instance)])
    error_message = "Worker instance type must be one of: m5n.xlarge, m5n.large, m5d.xlarge, m5d.large"
  }
}

variable "eks_additional_admin_roles" {
  type        = list(string)
  description = "Additional IAM roles to add as cluster administrators"
  default     = []

  validation {
    condition     = alltrue([for arn in var.eks_additional_admin_roles : can(regex("^arn:aws:iam::[0-9]{12}:role/[a-zA-Z0-9+=,.@_-]+$", arn))])
    error_message = "All role ARNs must be valid IAM role ARNs in the format: arn:aws:iam::<account-id>:role/<role-name>"
  }
}

###############################
######### Route53 #############
###############################

variable "domain_name" {
  type        = string
  description = "Main domain name for sub-domains"
  default     = ""
}

variable "create_public_zone" {
  description = "Whether to create the public Route 53 zone"
  type        = bool
  default     = false
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

###############################
########## ArgoCD #############
###############################

variable "argocd_config" {
  type = object({
    enabled = optional(bool, true)
    privatelink = optional(object({
      enabled                     = bool
      endpoint_allowed_principals = list(string)
      additional_aws_regions      = list(string)
    }))
    vcs = optional(object({
      organization = string
      repository   = string
      github = optional(object({
        enabled                   = bool
        githubapp_secret_name     = string
        github_private_key_secret = string
      }))
      gitlab = optional(object({
        enabled                 = bool
        oauth_secret_name       = string
        credentials_secret_name = string
      }))
    }))
    rbac = optional(object({
      sso_admin_group        = string
      users_rbac_rules       = list(string)
      users_additional_rules = list(string)
    }))
  })
  validation {
    condition     = !var.argocd_config.enabled || (var.argocd_config.vcs != null && var.argocd_config.vcs.organization != "" && var.argocd_config.vcs.repository != "")
    error_message = "When ArgoCD is enabled, vcs configuration must be provided with non-empty organization and repository"
  }
  validation {
    condition     = !var.argocd_config.enabled || (var.argocd_config.vcs != null && ((var.argocd_config.vcs.github != null && var.argocd_config.vcs.github.enabled) || (var.argocd_config.vcs.gitlab != null && var.argocd_config.vcs.gitlab.enabled)))
    error_message = "When ArgoCD is enabled, either GitHub or GitLab Dex configuration must be provided"
  }
  description = "ArgoCD configuration"
  default = {
    enabled = true
    privatelink = {
      enabled                     = false
      endpoint_allowed_principals = []
      additional_aws_regions      = []
    }
    vcs = {
      organization = ""
      repository   = ""
    }
    rbac = {
      sso_admin_group        = ""
      users_rbac_rules       = []
      users_additional_rules = []
    }
  }
}

################################
#### Prometheus Endpoint #######
################################

variable "prometheus_endpoint_config" {
  type = object({
    enabled                 = bool
    endpoint_service_name   = string
    endpoint_service_region = string
    additional_cidr_blocks  = list(string)
  })
  description = "Prometheus endpoint configuration"
  default = {
    enabled                 = false
    endpoint_service_name   = ""
    endpoint_service_region = ""
    additional_cidr_blocks  = []
  }
}

################################
#### Grafana Privatelink ######
################################

variable "grafana_privatelink_config" {
  type = object({
    enabled                     = bool
    endpoint_allowed_principals = optional(list(string), [])
    additional_aws_regions      = optional(list(string), [])
  })
  description = "Grafana privatelink configuration"
  default = {
    enabled = false
    endpoint_allowed_principals = []
    additional_aws_regions      = []
  }
}