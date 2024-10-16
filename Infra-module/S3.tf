locals {
  s3_default_config = {
    force_destroy                         = true
    ignore_public_acls                    = true
    block_public_policy                   = true
    block_public_acls                     = true
    attach_deny_insecure_transport_policy = true
    attach_elb_log_delivery_policy        = false
    attach_lb_log_delivery_policy         = false
    versioning                            = true
    encryption                            = true
    lifecycle_rule = [
      {
        id      = "expire-after-ten-years"
        enabled = true
        expiration = {
          days = 3650
        }
      }
    ]
  }
  s3_config  = yamldecode(file("${path.module}/s3_buckets.yaml"))
  s3_buckets = { for name, config in local.s3_config : name => merge(local.s3_default_config, config) }
  # s3_config = {
  #   "logs-ingress" = {
  #     versioning                     = true
  #     force_destroy                  = true
  #     ignore_public_acls             = true
  #     block_public_policy            = true
  #     block_public_acls              = false
  #     attach_elb_log_delivery_policy = true
  #     attach_lb_log_delivery_policy  = true
  #     lifecycle_rule = [
  #       {
  #         id      = "expire-after-one-year"
  #         enabled = true
  #         expiration = {
  #           days = 365
  #         }
  #       }
  #     ]
  #   }
  # }
}


module "s3_buckets" {
  source                                = "terraform-aws-modules/s3-bucket/aws"
  version                               = "~> 4.2.1"
  for_each                              = local.s3_buckets
  bucket                                = lower("${var.project}-${var.environment}-${each.key}-${random_string.random[each.key].result}")
  acl                                   = null
  force_destroy                         = each.value.force_destroy
  attach_elb_log_delivery_policy        = each.value.attach_elb_log_delivery_policy
  attach_lb_log_delivery_policy         = each.value.attach_lb_log_delivery_policy
  block_public_acls                     = each.value.block_public_acls
  block_public_policy                   = each.value.block_public_policy
  ignore_public_acls                    = each.value.ignore_public_acls
  attach_deny_insecure_transport_policy = each.value.attach_deny_insecure_transport_policy
  restrict_public_buckets               = true
  lifecycle_rule                        = each.value.lifecycle_rule
  versioning = {
    enabled = each.value.versioning
  }
  server_side_encryption_configuration = each.value.encryption ? {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  } : {}
  tags = merge(local.tags, {
    Name = lower("${var.project}-${var.environment}-${each.key}-${random_string.random[each.key].result}")
  })
  # for_each      = local.s3_config
  # bucket        = "hyperspace-${var.environment}-${each.key}-${random_string.random[each.key].result}"
  # tags          = local.tags
  # acl           = null
  # policy        = try(each.value.existing_policy_arn, null)
  # attach_policy = try(each.value.existing_policy_arn, null) != null
  # force_destroy = try(each.value.force_destroy, false)
  # versioning = {
  #   enabled = try(each.value.versioning, false)
  # }
  # attach_lb_log_delivery_policy  = try(each.value.attach_lb_log_delivery_policy, false)
  # attach_elb_log_delivery_policy = try(each.value.attach_elb_log_delivery_policy, false)
  # ignore_public_acls             = try(each.value.ignore_public_acls, false)
  # block_public_policy            = try(each.value.block_public_policy, false)
  # block_public_acls              = try(each.value.block_public_acls, false)
  # lifecycle_rule                 = try(each.value.lifecycle_rule, [])
}

resource "random_string" "random" {
  for_each = local.s3_config
  length   = 8
  upper    = false
  lower    = true
  numeric  = false
  special  = false
}