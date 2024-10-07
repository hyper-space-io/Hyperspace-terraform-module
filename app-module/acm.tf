locals {
  create_acm   = var.domain_name != "" ? true : false
  internal_acm = var.domain_name != "" ? module.acm["internal_acm"].acm_certificate_arn : var.internal_acm_arn != "" ? var.internal_acm_arn : ""
  external_acm = var.domain_name != "" ? module.acm["regular"].acm_certificate_arn : var.external_acm_arn != "" ? var.external_acm_arn : ""
  acm_config = {
    regular = {
      domain_name = var.domain_name
      subject_alternative_names = [
        "*.${var.domain_name}",
      ]
      create_certificate = local.create_acm
    },
    internal_acm = {
      domain_name = local.internal_domain_name
      subject_alternative_names = [
        "*.${local.internal_domain_name}",
      ]
      create_certificate = local.create_acm
    }
  }
}
module "acm" {
  source                    = "terraform-aws-modules/acm/aws"
  version                   = "5.0.1"
  for_each                  = local.acm_config
  create_certificate        = each.value.create_certificate
  domain_name               = each.value.domain_name
  zone_id                   = each.key == "regular" ? aws_route53_zone.zones["external"].zone_id : aws_route53_zone.internal_domain.0.zone_id
  subject_alternative_names = each.value.subject_alternative_names
  tags                      = local.tags
  validation_method         = "DNS"
  wait_for_validation       = true
  depends_on                = [aws_route53_record.internal_domain_ns]
}