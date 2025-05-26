locals {
  internal_domain_name = var.domain_name != "" ? "internal.hyperspace.${var.environment}.${var.domain_name}" : ""
  public_domain_name   = var.domain_name != "" ? "external.hyperspace.${var.environment}.${var.domain_name}" : ""
  create_records       = var.domain_name != "" ? 1 : 0
}

module "external_zone" {
  count   = var.create_public_zone && local.public_domain_name != "" ? 1 : 0
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 4.1.0"
  zones = {
    external = {
      domain_name = "${var.environment}.${var.domain_name}"
      comment     = "Public hosted zone for ${local.public_domain_name}"
      tags = merge(local.tags, {
        Name = local.public_domain_name
        Type = "public"
      })
    }
  }
}

module "internal_zone" {
  count   = local.create_private_zone && local.internal_domain_name != "" ? 1 : 0
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 4.1.0"
  zones = {
    internal = {
      domain_name = local.internal_domain_name
      comment     = "Private hosted zone for ${local.internal_domain_name}"
      vpc = [
        {
          vpc_id = local.vpc_id
        }
      ]
      tags = merge(local.tags, {
        Name = local.internal_domain_name
        Type = "private"
      })
    }
  }
}

resource "aws_route53_record" "external_wildcard" {
  count      = var.create_eks && (var.create_public_zone || var.existing_public_zone_id != null) ? 1 : 0
  zone_id    = local.public_zone_id
  name       = "*"
  type       = "CNAME"
  ttl        = "300"
  records    = [data.aws_lb.external_ingress[0].dns_name]
  depends_on = [helm_release.nginx-ingress, time_sleep.wait_for_external_ingress]
}

resource "aws_route53_record" "internal_wildcard" {
  count      = var.create_eks && (local.create_private_zone || var.existing_private_zone_id != null) ? 1 : 0
  zone_id    = local.private_zone_id
  name       = "*"
  type       = "CNAME"
  ttl        = "300"
  records    = [data.aws_lb.internal_ingress[0].dns_name]
  depends_on = [helm_release.nginx-ingress, time_sleep.wait_for_internal_ingress]
}