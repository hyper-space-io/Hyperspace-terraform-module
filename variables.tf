###############################
########## Global #############
###############################

variable "terraform_role" {
  type        = string
  description = "Terraform role to assume. If not set (null), no role will be assumed"
  default     = null
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID"
}

variable "project" {
  type        = string
  description = "Name of the project"
  default     = "hyperspace"
}

variable "environment" {
  type        = string
  description = "Environment Name"
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

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "List of availability zones to deploy the resources. Leave empty to automatically select based on the region and the variable num_zones."
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "existing_vpc_id" {
  description = "ID of an existing VPC to use instead of creating a new one"
  type        = string
  default     = null
}

variable "existing_private_subnets" {
  description = "The private subnets for the existing VPC"
  type        = list(string)
  default     = []
}

variable "existing_public_subnets" {
  description = "The public subnets for the existing VPC"
  type        = list(string)
  default     = []
}

variable "num_zones" {
  type        = number
  default     = 2
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

variable "cluster_endpoint_public_access" {
  description = "Whether to enable public access to the EKS cluster endpoint"
  type        = bool
  default     = false
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
}

variable "eks_additional_admin_roles_policy" {
  type        = string
  description = "IAM policy for the EKS additional admin roles"
  default     = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
}

###############################
######### Route53 #############
###############################

variable "domain_name" {
  type        = string
  description = "Main domain name for sub-domains"
  default     = null
  sensitive   = false
}

variable "create_public_zone" {
  description = "Whether to create the public Route 53 zone"
  type        = bool
  default     = true
}

variable "domain_validation_id" {
  description = "The domain validation ID for the public Route 53 zone"
  type        = string
  default     = null
}

variable "existing_public_zone_id" {
  type        = string
  description = "Existing public Route 53 zone"
  default     = null
  validation {
    condition     = (var.existing_public_zone_id == null && var.create_public_zone) || (var.existing_public_zone_id != null && !var.create_public_zone)
    error_message = "Either provide an existing public zone ID (and set create_public_zone to false) or set create_public_zone to true (and leave existing_public_zone_id empty)."
  }
}

variable "existing_private_zone_id" {
  type        = string
  description = "Existing private Route 53 zone"
  default     = null
  validation {
    condition     = var.existing_private_zone_id == null || var.existing_private_zone_id != null
    error_message = "Either provide an existing private zone ID or leave it as null."
  }
}

###############################
########## ArgoCD #############
###############################

variable "argocd_config" {
  type = object({
    enabled = optional(bool, true)
    privatelink = optional(object({
      enabled                     = optional(bool, false)
      endpoint_allowed_principals = optional(list(string), [])
      additional_aws_regions      = optional(list(string), [])
    }))
    vcs = optional(object({
      organization = string
      repository   = string
      github = optional(object({
        enabled                   = bool
        github_app_enabled        = optional(bool, false)
        github_app_secret_name    = optional(string, "argocd/github_app")
        github_private_key_secret = optional(string, "argocd/github_app_private_key")
      }))
      gitlab = optional(object({
        enabled                 = bool
        oauth_enabled           = optional(bool, false)
        oauth_secret_name       = optional(string, "argocd/gitlab_oauth")
        credentials_secret_name = optional(string, "argocd/gitlab_credentials")
      }))
    }))
    rbac = optional(object({
      sso_admin_group        = optional(string)
      users_rbac_rules       = optional(list(string), [])
      users_additional_rules = optional(list(string), [])
    }))
  })
  validation {
    condition     = !var.argocd_config.enabled || (var.argocd_config.vcs != null && var.argocd_config.vcs.organization != "" && var.argocd_config.vcs.repository != "")
    error_message = "When ArgoCD is enabled, vcs configuration must be provided with non-empty organization and repository"
  }
  validation {
    condition = !var.argocd_config.enabled || (var.argocd_config.vcs != null && (
      (try(var.argocd_config.vcs.github.enabled, false)) ||
      (try(var.argocd_config.vcs.gitlab.enabled, false))
    ))
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
    enabled                 = optional(bool, false)
    endpoint_service_name   = optional(string, "")
    endpoint_service_region = optional(string, "")
    additional_cidr_blocks  = optional(list(string), [])
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
#### Grafana Privatelink #######
################################

variable "grafana_privatelink_config" {
  type = object({
    enabled                     = optional(bool, false)
    endpoint_allowed_principals = optional(list(string), [])
    additional_aws_regions      = optional(list(string), [])
  })
  description = "Grafana privatelink configuration"
  default = {
    enabled                     = false
    endpoint_allowed_principals = []
    additional_aws_regions      = []
  }
}