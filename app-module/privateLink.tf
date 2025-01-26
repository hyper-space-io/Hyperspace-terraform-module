# module "privatelink" {
#   source  = "BorisLabs/privatelink/aws"
#   version = "1.1.2"
#   acceptance_required = false
#   allowed_principals =  [ { "principal": "arn:aws:iam::418316469434:root" } ]
#   network_load_balancer_arns = [data.aws_lb.nlb.arn]
#   service_name = "argocd-server-${local.cluster_name}"
#   service_tags = local.tags
#   supported_ip_address_types = ["ipv4"]
# }

resource "aws_vpc_endpoint_service" "argocd_server" {
  acceptance_required = false
  network_load_balancer_arns = [data.aws_lb.nlb.arn]
  allowed_principals =  ["arn:aws:iam::418316469434:root"]
  tags = local.tags
  supported_regions = [var.aws_region]
  private_dns_name = "argocd-server-${local.cluster_name}"
}