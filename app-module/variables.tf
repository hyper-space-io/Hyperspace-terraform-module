# variables.tf
variable "organization" {
  description = "Terraform Cloud organization name"
  type        = string
}

variable "infra_workspace_name" {
  description = "Terraform Cloud workspace name where infrastructure is defined"
  type        = string
}