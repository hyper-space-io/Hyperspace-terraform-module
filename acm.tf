locals {
  create_acm = var.domain_name != "" ? true : false
  acm_config = {
    external_acm = (var.create_public_zone && local.public_domain_name != "") ? {
      domain_name = local.public_domain_name
      subject_alternative_names = [
        "*.${local.public_domain_name}",
      ]
      create_certificate = local.create_acm
      create_route53_records = var.existing_public_zone != "" ? true : false
      zone_id = var.existing_public_zone
    } : null,
    internal_acm = local.internal_domain_name != "" ? {
      domain_name = local.internal_domain_name
      subject_alternative_names = [
        "*.${local.internal_domain_name}",
      ]
      create_certificate = local.create_acm
      create_route53_records = false
    } : null
  }
}

module "acm" {
  source                    = "terraform-aws-modules/acm/aws"
  version                   = "~> 5.1.1"
  for_each                  = { for k, v in local.acm_config : k => v if v != null }
  create_certificate        = each.value.create_certificate
  domain_name               = each.value.domain_name
  subject_alternative_names = each.value.subject_alternative_names
  tags                      = local.tags
  create_route53_records    = try(each.value.create_route53_records, false)
  zone_id                   = try(each.value.zone_id, null)
  validation_method         = "DNS"
  wait_for_validation       = true
}