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
  allowed_principals         = jsondecode(var.argocd_endpoint_allowed_principals)
  supported_regions          = distinct(concat([var.aws_region], jsondecode(var.argocd_endpoint_additional_aws_regions)))
  private_dns_name           = "argocd.${var.project}.${local.internal_domain_name}"

  tags = merge(local.tags, {
    Name = "ArgoCD Endpoint Service - ${var.project}-${var.environment}"
  })

  depends_on = [null_resource.wait_for_nlb]
}