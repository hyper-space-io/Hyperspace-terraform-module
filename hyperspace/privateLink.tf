resource "null_resource" "wait_for_nlb" {
  count = var.enable_argocd && local.create_eks && var.enable_argocd_private_link ? 1 : 0
  provisioner "local-exec" {
    command = <<EOF
      until STATE=$(aws elbv2 describe-load-balancers --load-balancer-arns ${data.aws_lb.argocd_lb[0].arn} --query 'LoadBalancers[0].State.Code' --output text) && [ "$STATE" = "active" ]; do
        echo "Waiting for NLB to become active... Current state: $STATE"
        sleep 10
      done
      echo "NLB is now active"
    EOF
  }

  triggers = {
    nlb_arn = data.aws_lb.argocd_lb[0].arn
  }
}

resource "aws_vpc_endpoint_service" "argocd_server" {
  count                      = var.enable_argocd && local.create_eks && var.enable_argocd_private_link ? 1 : 0
  acceptance_required        = false
  network_load_balancer_arns = [data.aws_lb.argocd_lb[0].arn]
  allowed_principals         = ["arn:aws:iam::${var.hyperspace_account_id}:root"]
  supported_regions          = [var.aws_region, "eu-central-1"]
  private_dns_name           = "argocd.${var.project}.${local.internal_domain_name}"

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment} ArgoCD Endpoint Service"
  })

  depends_on = [null_resource.wait_for_nlb]
}