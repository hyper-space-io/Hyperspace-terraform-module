locals {
  create_acm = var.domain_name != "" ? true : false

  # Non-sensitive configuration
  acm_enabled = {
    external = var.create_public_zone
    internal = true
  }

  # Sensitive values in separate maps
  external_acm_config = local.public_domain_name != "" ? {
    domain_name = local.public_domain_name
    subject_alternative_names = [
      "*.${local.public_domain_name}",
    ]
    create_certificate = local.create_acm
  } : null

  internal_acm_config = local.internal_domain_name != "" ? {
    domain_name = local.internal_domain_name
    subject_alternative_names = [
      "*.${local.internal_domain_name}",
    ]
    create_certificate = local.create_acm
  } : null
}

module "acm" {
  source                    = "terraform-aws-modules/acm/aws"
  version                   = "~> 5.1.1"
  for_each                  = {
    for k, enabled in local.acm_enabled : k => nonsensitive(
      k == "external" ? local.external_acm_config : local.internal_acm_config
    ) if enabled && (k == "external" ? local.external_acm_config != null : local.internal_acm_config != null)
  }
  create_certificate        = each.value.create_certificate
  domain_name               = each.value.domain_name
  subject_alternative_names = each.value.subject_alternative_names
  tags                      = local.tags
  create_route53_records    = false
  validation_method         = "DNS"
  wait_for_validation       = true
}