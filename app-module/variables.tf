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
  type = list(object({
    type   = string
    id     = string
    name   = string
    config = map(string)
  }))
  default     = []
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