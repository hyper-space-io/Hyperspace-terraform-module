variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to create resources in"
}

variable "source_account_id" {
  type        = string
  description = "Source AWS account ID that will assume the role"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to resources"
} 