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
  policy        = each.value.existing_policy_arn
  attach_policy = each.value.existing_policy_arn != null ? true : false
  force_destroy = each.value.force_destroy == true ? true : false
  versioning = {
    enabled = each.value.versioning
  }
  attach_lb_log_delivery_policy  = each.value.attach_lb_log_delivery_policy != true ? false : true
  attach_elb_log_delivery_policy = each.value.attach_elb_log_delivery_policy != true ? false : true
  ignore_public_acls             = each.value.ignore_public_acls != null ? each.value.ignore_public_acls : false
  block_public_policy            = each.value.block_public_policy != null ? each.value.block_public_policy : false
  block_public_acls              = each.value.block_public_acls != null ? each.value.block_public_acls : false
}

resource "random_string" "random" {
  for_each = local.s3_config
  length   = 8
  upper    = false
  lower    = true
  numeric  = false
  special  = false
}