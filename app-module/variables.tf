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