locals {
  # Only create Route53 records for validation if we have a validation zone ID
  create_route53_records = local.validation_zone_id != null

  # Map domains to their respective zones
  validation_zones = {
    (var.domain_name) = local.validation_zone_id
  }
}

module "external_acm" {
  count       = local.create_external_lb ? 1 : 0
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
  zones                  = local.validation_zones
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
  zones                  = local.validation_zones
  wait_for_validation    = true
}