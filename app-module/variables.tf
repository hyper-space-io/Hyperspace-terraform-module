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
  description = "The domain name to create if we don't have an existing domain configured"
  type        = string
  default     = ""
}

variable "internal_acm_arn" {
  description = "ARN of an ACM certificate to use - will be created if not configured"
  default     = ""
  type        = string
}

variable "external_acm_arn" {
  description = "ARN of an ACM certificate to use for external domains - will be created if not configured"
  default     = ""
  type        = string
}

variable "create_public_zone" {
  description = "Whether to create the public Route 53 zone"
  type        = bool
  default     = true
}