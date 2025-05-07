locals {
  create_acm = var.domain_name != "" ? true : false
  
  # Create a list of certificate configurations
  certificate_configs = [
    {
      name = "external"
      config = (var.create_public_zone && local.public_domain_name != "") ? {
        domain_name = local.public_domain_name
        subject_alternative_names = [
          "*.${local.public_domain_name}",
        ]
        create_certificate = local.create_acm
      } : null
    },
    {
      name = "internal"
      config = local.internal_domain_name != "" ? {
        domain_name = local.internal_domain_name
        subject_alternative_names = [
          "*.${local.internal_domain_name}",
        ]
        create_certificate = local.create_acm
      } : null
    }
  ]
}

module "acm" {
  source                    = "terraform-aws-modules/acm/aws"
  version                   = "~> 5.1.1"
  for_each                  = { for cert in local.certificate_configs : cert.name => cert.config if cert.config != null }
  create_certificate        = each.value.create_certificate
  domain_name               = each.value.domain_name
  subject_alternative_names = each.value.subject_alternative_names
  tags                      = local.tags
  create_route53_records    = false
  validation_method         = "DNS"
  wait_for_validation       = true
}