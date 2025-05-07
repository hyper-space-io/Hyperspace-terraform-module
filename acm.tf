locals {
  create_acm = var.domain_name != "" ? true : false
  
  # Create a list of certificate configurations
  certificate_configs = [
    {
      name = "external"
      enabled = var.create_public_zone
      domain_name = local.public_domain_name
      subject_alternative_names = [
        "*.${local.public_domain_name}",
      ]
      create_certificate = local.create_acm
    },
    {
      name = "internal"
      enabled = true
      domain_name = local.internal_domain_name
      subject_alternative_names = [
        "*.${local.internal_domain_name}",
      ]
      create_certificate = local.create_acm
    }
  ]
}

module "acm" {
  source                    = "terraform-aws-modules/acm/aws"
  version                   = "~> 5.1.1"
  for_each                  = { for cert in local.certificate_configs : cert.name => cert if cert.enabled && cert.domain_name != "" }
  create_certificate        = each.value.create_certificate
  domain_name               = each.value.domain_name
  subject_alternative_names = each.value.subject_alternative_names
  tags                      = local.tags
  create_route53_records    = false
  validation_method         = "DNS"
  wait_for_validation       = true
}