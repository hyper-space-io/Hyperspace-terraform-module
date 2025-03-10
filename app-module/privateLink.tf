resource "null_resource" "wait_for_nlb" {
  count = var.enable_argocd ? 1 : 0
  provisioner "local-exec" {
    command = <<EOF
      until STATE=$(aws elbv2 describe-load-balancers --load-balancer-arns ${data.aws_lb.nlb.arn} --query 'LoadBalancers[0].State.Code' --output text) && [ "$STATE" = "active" ]; do
        echo "Waiting for NLB to become active... Current state: $STATE"
        sleep 10
      done
      echo "NLB is now active"
    EOF
  }

  triggers = {
    nlb_arn = data.aws_lb.nlb.arn
  }
}

resource "aws_vpc_endpoint_service" "argocd_server" {
  count                      = var.enable_argocd ? 1 : 0
  acceptance_required        = false
  network_load_balancer_arns = [data.aws_lb.nlb.arn]
  allowed_principals         = ["arn:aws:iam::418316469434:root"]
  supported_regions          = [var.aws_region]
  private_dns_name           = "argocd-server-${local.internal_domain_name}"

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment} ArgoCD Endpoint Service"
  })

  depends_on = [null_resource.wait_for_nlb]
}