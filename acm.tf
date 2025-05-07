locals {
  create_acm = var.domain_name != "" ? true : false
}

module "external_acm" {
  count                       = var.create_public_zone && local.public_domain_name != "" ? 1 : 0
  source                      = "terraform-aws-modules/acm/aws"
  version                     = "~> 5.1.1"
  create_certificate          = local.create_acm
  domain_name                 = local.public_domain_name
  subject_alternative_names   = [
    "*.${local.public_domain_name}",
  ]
  tags                        = local.tags
  create_route53_records      = false
  validation_method           = "DNS"
  wait_for_validation         = true
}

module "internal_acm" {
  count                       = local.internal_domain_name != "" ? 1 : 0
  source                      = "terraform-aws-modules/acm/aws"
  version                     = "~> 5.1.1"
  create_certificate          = local.create_acm
  domain_name                 = local.internal_domain_name
  subject_alternative_names   = [
    "*.${local.internal_domain_name}",
  ]
  tags                        = local.tags
  create_route53_records      = false
  validation_method           = "DNS"
  wait_for_validation         = true
}