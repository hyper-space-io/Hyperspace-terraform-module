resource "aws_vpc_endpoint_service" "argocd_server" {
  acceptance_required = false
  network_load_balancer_arns = [data.aws_lb.nlb.arn]
  allowed_principals =  ["arn:aws:iam::418316469434:root"]
  tags = local.tags
  supported_regions = [var.aws_region]
  private_dns_name = "argocd-server-${local.internal_domain_name}"
}