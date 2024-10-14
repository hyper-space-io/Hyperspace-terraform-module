locals {
  create_acm = var.domain_name != "" ? true : false
  acm_config = {
    external_acm = var.create_public_zone && local.public_domain_name != "" ? {
      domain_name = local.public_domain_name
      subject_alternative_names = [
        "*.${local.public_domain_name}",
      ]
      create_certificate = local.create_acm
    } : null,
    internal_acm = local.internal_domain_name != "" ? {
      domain_name = local.internal_domain_name
      subject_alternative_names = [
        "*.${local.internal_domain_name}",
      ]
      create_certificate = local.create_acm
    } : null
  }
}
module "acm" {
  source                    = "terraform-aws-modules/acm/aws"
  version                   = "5.0.1"
  for_each                  = { for k, v in local.acm_config : k => v if v != null }
  create_certificate        = each.value.create_certificate
  domain_name               = each.value.domain_name
  subject_alternative_names = each.value.subject_alternative_names
  tags                      = local.tags
  zone_id                   = contains("${each.key}", "external") ? module.zones["external"].route53_zone_zone_id : ""
  create_route53_records    = contains("${each.key}", "external") ? true : false
  validation_method         = "DNS"
  wait_for_validation       = true
}