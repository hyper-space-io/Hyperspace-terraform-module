module "privatelink" {
  source  = "BorisLabs/privatelink/aws"
  version = "1.1.2"
  acceptance_required = false
  allowed_principals =  [ { "principal": "arn:aws:iam::418316469434:root" } ]
  network_load_balancer_arns = [data.aws_lb.nlb.arn]
  service_name = "argocd-server-${local.cluster_name}"
  service_tags = local.tags
  supported_ip_address_types = ["ipv4"]
}