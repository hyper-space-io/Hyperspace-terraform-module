locals {
  create_route53_records = local.validation_zone_id != null ? true : false
}

module "external_acm" {
  count       = var.create_public_zone || var.existing_public_zone_id != "" ? 1 : 0
  source      = "terraform-aws-modules/acm/aws"
  version     = "~> 5.1.1"
  domain_name = local.public_domain_name
  subject_alternative_names = [
    "*.${local.public_domain_name}",
  ]
  tags                   = local.tags
  create_route53_records = local.create_route53_records
  validation_method      = "DNS"
  zone_id                = local.validation_zone_id
  wait_for_validation    = true
}

module "internal_acm" {
  count       = local.create_private_zone ? 1 : 0
  source      = "terraform-aws-modules/acm/aws"
  version     = "~> 5.1.1"
  domain_name = local.internal_domain_name
  subject_alternative_names = [
    "*.${local.internal_domain_name}",
  ]
  tags                   = local.tags
  create_route53_records = local.create_route53_records
  validation_method      = "DNS"
  zone_id                = local.validation_zone_id
  wait_for_validation    = true
}