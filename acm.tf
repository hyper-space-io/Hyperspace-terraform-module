locals {
  create_acm             = var.domain_name != "" ? true : false
  create_route53_records = local.create_acm && local.validation_zone_id != null ? true : false
  create_external_acm    = local.public_domain_name != "" && (var.create_public_zone || var.existing_public_zone_id != "")
  create_internal_acm    = local.internal_domain_name != "" && local.create_private_zone
}

module "external_acm" {
  source             = "terraform-aws-modules/acm/aws"
  version            = "~> 5.1.1"
  # Use create_certificate instead of count to conditionally create the certificate
  # This is the module's recommended approach for conditional creation - https://registry.terraform.io/modules/terraform-aws-modules/acm/aws/latest#conditional-creation-and-validation
  create_certificate = local.create_external_acm
  domain_name        = local.public_domain_name
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
  source             = "terraform-aws-modules/acm/aws"
  version            = "~> 5.1.1"
  # Use create_certificate instead of count to conditionally create the certificate
  # This is the module's recommended approach for conditional creation - https://registry.terraform.io/modules/terraform-aws-modules/acm/aws/latest#conditional-creation-and-validation
  create_certificate = local.create_internal_acm
  domain_name        = local.internal_domain_name
  subject_alternative_names = [
    "*.${local.internal_domain_name}",
  ]
  tags                   = local.tags
  create_route53_records = local.create_route53_records
  validation_method      = "DNS"
  zone_id                = local.validation_zone_id
  wait_for_validation    = true
}