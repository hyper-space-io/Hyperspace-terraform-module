########################
# GENERAL
########################

variable "project" {
  description = "Name of the project - this is used to generate names for resources"
  type        = string
  default     = "hyperspace"
}

variable "environment" {
  description = "The environment we are creating - used to generate names for resource"
  type        = string
  default     = "development"
}

variable "tags" {
  description = "List of tags to assign to resources created in this module"
  type        = map(any)
  default = {
    terraform = true
  }
}

variable "aws_region" {
  description = "This is used to define where resources are created and used"
  type        = string
  default     = "us-east-1"
}


########################
# VPC
########################

variable "vpc_cidr" {
  description = "Cidr of the vpc we will create in the format of X.X.X.X/16"
  type        = string
  default     = "10.10.100.0/16"
}

variable "num_zones" {
  description = "How many zones should we utilize for the eks nodes"
  type        = number
  default     = 2
  validation {
    condition     = var.num_zones <= length(data.aws_availability_zones.available.names)
    error_message = "The number of zones specified (num_zones) exceeds the number of available availability zones in the selected region."
  }
}

variable "availability_zones" {
  description = "List of availablity zones to deploy the resources"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Dictates if nat gateway is enabled or not"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Dictates if it is one nat gateway or multiple"
  type        = bool
  default     = false
}

variable "create_vpc_flow_logs" {
  type        = bool
  default     = false
  description = "Whether we create vpc flow logs or not"
}

variable "flow_logs_retention" {
  description = "vpc flow logs retention in days"
  type        = number
  default     = 14
}

variable "flow_log_group_class" {
  description = "vpc flow logs log group class in cloudwatch"
  type        = string
  default     = "value"
}