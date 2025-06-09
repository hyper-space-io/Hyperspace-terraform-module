locals {
  internal_domain_name = var.domain_name != "" ? "internal.hyperspace.${var.environment}.${var.domain_name}" : ""
  public_domain_name   = var.domain_name != "" ? "hyperspace.${var.environment}.${var.domain_name}" : ""
  create_records       = var.domain_name != "" ? 1 : 0
  
  # Combine main VPC with additional VPCs for private hosted zone
  private_zone_vpc_configs = concat(
    # Main VPC (always included)
    [{ vpc_id = local.vpc_id }],
    # Additional VPCs from user input
    [for vpc_id in var.additional_private_zone_vpc_ids : { vpc_id = vpc_id }]
  )
}

module "external_zone" {
  count   = local.create_public_zone ? 1 : 0
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 4.1.0"
  zones = {
    external = {
      domain_name = local.public_domain_name
      comment     = "Public hosted zone for ${local.public_domain_name}"
      tags = merge(local.tags, {
        Name = local.public_domain_name
        Type = "public"
      })
    }
  }
}

module "internal_zone" {
  count   = local.create_private_zone ? 1 : 0
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 4.1.0"
  zones = {
    internal = {
      domain_name = local.internal_domain_name
      comment     = "Private hosted zone for ${local.internal_domain_name}"
      vpc         = local.private_zone_vpc_configs
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