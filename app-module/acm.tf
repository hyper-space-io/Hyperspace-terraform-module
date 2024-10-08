locals {
  create_acm = var.domain_name != "" ? true : false
  acm_config = {
    external_acm = var.create_public_zone && var.domain_name != "" ? {
      domain_name = var.domain_name
      subject_alternative_names = [
        "*.${var.domain_name}",
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
  zone_id                   = each.key == "external_acm" && var.create_public_zone ? module.zones["external"].route53_zone_zone_id : module.zones.route53_zone_zone_id["internal"]
  subject_alternative_names = each.value.subject_alternative_names
  tags                      = local.tags
  validation_method         = "DNS"
  wait_for_validation       = true
  depends_on                = [module.zones]
}