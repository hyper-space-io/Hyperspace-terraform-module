locals {
  s3_config = {
    "logs-ingress" = {
      versioning                     = true
      force_destroy                  = true
      ignore_public_acls             = true
      block_public_policy            = true
      block_public_acls              = false
      attach_elb_log_delivery_policy = true
      attach_lb_log_delivery_policy  = true
    }
  }
}
module "s3_buckets" {
  source        = "terraform-aws-modules/s3-bucket/aws"
  version       = "4.1.1"
  for_each      = local.s3_config
  bucket        = "hyperspace-${var.environment}-${each.key}-${random_string.random[each.key].result}"
  tags          = var.tags
  acl           = null
  policy        = try(each.value.existing_policy_arn, null)
  attach_policy = try(each.value.existing_policy_arn, null) != null
  force_destroy = try(each.value.force_destroy, false)
  versioning = {
    enabled = try(each.value.versioning, false)
  }
  attach_lb_log_delivery_policy  = try(each.value.attach_lb_log_delivery_policy, false)
  attach_elb_log_delivery_policy = try(each.value.attach_elb_log_delivery_policy, false)
  ignore_public_acls             = try(each.value.ignore_public_acls, false)
  block_public_policy            = try(each.value.block_public_policy, false)
  block_public_acls              = try(each.value.block_public_acls, false)
}

resource "random_string" "random" {
  for_each = local.s3_config
  length   = 8
  upper    = false
  lower    = true
  numeric  = false
  special  = false
}