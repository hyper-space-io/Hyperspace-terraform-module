locals {
  internal_domain_name = var.domain_name != "" ? "internal.${var.environment}.${var.domain_name}" : ""
  public_domain_name   = var.domain_name != "" ? "${var.environment}.${var.domain_name}" : ""
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
      })
    }
  }
}

resource "aws_route53_record" "wildcard" {
  count      = (var.existing_public_zone_id != null || var.create_public_zone) ? 1 : 0
  zone_id    = local.public_zone_id
  name       = "*"
  type       = "CNAME"
  ttl        = "300"
  records    = [data.kubernetes_ingress_v1.external_ingress[0].status[0].load_balancer[0].ingress[0].hostname]
  depends_on = [helm_release.nginx-ingress]
}

resource "aws_route53_record" "internal_wildcard" {
  count      = local.create_records
  zone_id    = local.private_zone_id
  name       = "*"
  type       = "CNAME"
  ttl        = "300"
  records    = [data.kubernetes_ingress_v1.internal_ingress.status[0].load_balancer[0].ingress[0].hostname]
  depends_on = [helm_release.nginx-ingress]
}