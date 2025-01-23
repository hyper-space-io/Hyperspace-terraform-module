module "infra" {
  source = "github.com/hyper-space-io/Hyperspace-terraform-module/Infra-module?ref=setup-cluster-tools"
  dex_connectors = var.dex_connectors
  domain_name = "hyper-space.xyz"
  environment = "dev-idan"
  flow_log_group_class = "INFREQUENT_ACCESS"
  worker_instance_type = ["m5n.large"]
  vpc_cidr = "10.11.0.0/16"
}
