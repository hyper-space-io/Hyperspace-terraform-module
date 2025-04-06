locals {
  internal_domain_name = var.domain_name != "" ? "tfe.internal.${var.environment}.${var.domain_name}" : ""
  public_domain_name   = var.domain_name != "" ? "tfe.${var.environment}.${var.domain_name}" : ""
  create_records       = var.domain_name != "" ? 1 : 0

  zones = {
    external = (var.create_public_zone && local.public_domain_name != "") ? {
      domain_name = "tfe.${var.environment}.${var.domain_name}"
      comment     = "Public hosted zone for ${local.public_domain_name}"
      tags = merge(local.tags, {
        Name = local.public_domain_name
      })
    } : null

    internal = local.internal_domain_name != "" ? {
      domain_name = local.internal_domain_name
      comment     = "Private hosted zone for ${local.internal_domain_name}"
      vpc = [
        {
          vpc_id = module.vpc.vpc_id
        }
      ]
      tags = merge(local.tags, {
        Name = local.internal_domain_name
      })
    } : null
  }
}

module "zones" {
  source     = "terraform-aws-modules/route53/aws//modules/zones"
  version    = "~> 4.1.0"
  zones      = { for k, v in local.zones : k => v if v != null }
  depends_on = [module.acm]
}

resource "aws_route53_record" "wildcard" {
  count      = var.create_public_zone && local.create_eks ? local.create_records : 0
  zone_id    = module.zones.route53_zone_zone_id["external"]
  name       = "*"
  type       = "CNAME"
  ttl        = "300"
  records    = [data.kubernetes_ingress_v1.external_ingress[0].status.0.load_balancer.0.ingress.0.hostname]
  depends_on = [helm_release.nginx-ingress, module.eks, module.vpc]
}

resource "aws_route53_record" "internal_wildcard" {
  count      = local.create_eks ? local.create_records : 0
  zone_id    = module.zones.route53_zone_zone_id["internal"]
  name       = "*"
  type       = "CNAME"
  ttl        = "300"
  records    = [data.kubernetes_ingress_v1.internal_ingress[0].status.0.load_balancer.0.ingress.0.hostname]
  depends_on = [helm_release.nginx-ingress, module.eks, module.vpc]
}

resource "aws_route53_record" "argocd_lb" {
  count      = var.enable_argocd && local.create_eks ? local.create_records : 0
  zone_id    = module.zones.route53_zone_zone_id["internal"]
  name       = "argocd.${local.internal_domain_name}"
  type       = "A"
  
  alias {
    name                   = data.kubernetes_service.argocd_server[0].status.0.load_balancer.0.ingress.0.hostname
    zone_id                = data.aws_lb.argocd_lb.zone_id
    evaluate_target_health = true
  }
  
  depends_on = [helm_release.argocd, data.kubernetes_service.argocd_server]
}