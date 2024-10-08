locals {
  internal_domain_name = var.domain_name != "" ? "internal.${var.domain_name}" : ""
  create_records       = var.domain_name != "" ? 1 : 0
  zones = {
    external = var.create_public_zone && var.domain_name != "" ? {
      domain_name = var.domain_name
      comment     = "Public hosted zone for ${var.domain_name}"
      tags = merge(local.tags, {
        Name = var.domain_name
      })
    } : null

    internal = local.internal_domain_name != "" ? {
      domain_name = local.internal_domain_name
      comment     = "Private hosted zone for ${local.internal_domain_name}"
      vpc = [
        {
          vpc_id = local.vpc_module.vpc_id
        }
      ]
      tags = merge(local.tags, {
        Name = local.internal_domain_name
      })
    } : null
  }
  zones_merged = { for k, v in local.zones : k => v if v != null }
}

module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 4.1.0"
  zones   = { for k, v in local.zones : k => v if v != null }
}

resource "aws_route53_record" "wildcard" {
  count      = var.create_public_zone ? local.create_records : 0
  zone_id    = module.zones["external"].route53_zone_zone_id
  name       = "*"
  type       = "CNAME"
  ttl        = "300"
  records    = [data.kubernetes_ingress_v1.ingress.status.0.load_balancer.0.ingress.0.hostname]
  depends_on = [helm_release.nginx-ingress]
}

resource "aws_route53_record" "internal_wildcard" {
  count      = local.create_records
  zone_id    = module.zones["internal"].route53_zone_zone_id
  name       = "*"
  type       = "CNAME"
  ttl        = "300"
  records    = [data.kubernetes_ingress_v1.internal_ingress.status.0.load_balancer.0.ingress.0.hostname]
  depends_on = [helm_release.nginx-ingress]
}