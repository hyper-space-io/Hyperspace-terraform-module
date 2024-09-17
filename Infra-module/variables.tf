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
    terraform  = true
    hyperspace = true
  }
}

variable "aws_region" {
  description = "This is used to define where resources are created and used"
  type        = string
  default     = "us-east-1"
  validation {
    condition     = contains(["us-east-1", "us-west-1", "eu-west-1"], var.aws_region)
    error_message = "Hyperspace currently does not support this region, valid values: [us-east-1, eu-west-1, eu-central-1]."
  }
}


########################
# VPC
########################

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g., 10.10.100.0/16) - defines the IP range for resources within the VPC."
  type        = string
  default     = "10.10.100.0/16"
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(\\d{1,2})$", var.vpc_cidr))
    error_message = "The VPC CIDR must be a valid CIDR block in the format X.X.X.X/XX."
  }
}

variable "num_zones" {
  description = "How many zones should we utilize for the eks nodes"
  type        = number
  default     = 2
  validation {
    condition     = var.num_zones <= length(data.aws_availability_zones.available.names)
    error_message = "The number of zones specified (num_zones) exceeds the number of available availability zones in the selected region. The number of available AZ's is ${length(data.aws_availability_zones.available.names)}"
  }
}

variable "availability_zones" {
  description = "List of availability zones to deploy the resources. Leave empty to automatically select based on the region and the variable num_zones."
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Dictates if nat gateway is enabled or not"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Whether to create a single NAT gateway (true) or one per availability zone (false)."
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
  description = "VPC flow logs log group class in CloudWatch. Leave empty for default or provide a specific class."
  type        = string
  default     = ""
}

variable "flow_log_file_format" {
  description = "The format for the flow log."
  type        = string
  default     = "parquet"
  validation {
    condition     = contains(["parquet", "plain-text", "json"], var.flow_log_file_format)
    error_message = "Flow log file format must be one of 'parquet', 'plain-text', or 'json'."
  }
}

variable "tfc_agent_token" {
  type      = string
  sensitive = true
}