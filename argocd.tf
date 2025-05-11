resource "helm_release" "argocd" {
  count            = local.argocd_enabled ? 1 : 0
  chart            = "argo-cd"
  namespace        = "argocd"
  name             = "argocd"
  version          = "7.7.11"
  depends_on       = [helm_release.nginx-ingress, module.eks_blueprints_addons, module.eks]
  create_namespace = true
  cleanup_on_fail  = true
  repository       = "https://argoproj.github.io/argo-helm"

  values = [
    yamlencode({
      global = {
        domain = "argocd.${local.internal_domain_name}"
      }
      dex = {
        enabled = true
      }
      redis = {
      }
      configs = {
        rbac = {
          "policy.default" = local.argocd_rbac_policy_default
          "policy.csv"     = join("\n", local.argocd_rbac_policy_rules)
        }
        cm                  = local.argocd_configmap_values
        credentialTemplates = sensitive(local.argocd_credential_templates)
      }
      server = {
        service = local.argocd_privatelink_enabled ? {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-internal"               = "true"
            "service.beta.kubernetes.io/aws-load-balancer-type"                   = "nlb-ip"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"                 = "internal"
            "service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy" = "ELBSecurityPolicy-TLS13-1-2-2021-06"
          }
          } : {
          type        = "ClusterIP"
          annotations = {}
        }
        autoscaling = {
          enabled     = true
          minReplicas = "1"
        }
        extraArgs = ["--insecure"]
        ingress = {
          enabled          = true
          ingressClassName = "nginx-internal"
          hosts = [
            "argocd.${local.internal_domain_name}"
          ]
          https = false
        }
      }
      applicationSet = {
        replicas = 2
      }
      repoServer = {
        autoscaling = {
          enabled     = true
          minReplicas = "1"
        }
      }
    })
  ]
}

##################################
####### ArgoCD Privatelink #######
##################################

resource "aws_vpc_endpoint_service" "argocd" {
  count                      = local.argocd_privatelink_enabled ? 1 : 0
  acceptance_required        = false
  network_load_balancer_arns = [data.aws_lb.argocd_privatelink_nlb[0].arn]
  allowed_principals         = local.argocd_privatelink_allowed_principals
  supported_regions          = local.argocd_privatelink_supported_regions
  private_dns_name           = "argocd.${var.project}.${local.internal_domain_name}"

  tags = merge(local.tags, {
    Name = "ArgoCD Endpoint Service - ${var.project}-${var.environment}"
  })

  depends_on = [data.aws_lb.argocd_privatelink_nlb[0]]
}

resource "random_password" "argocd_readonly" {
  count  = local.argocd_privatelink_enabled ? 1 : 0
  length = 16
}

resource "aws_secretsmanager_secret" "argocd_readonly_password" {
  count                   = local.argocd_privatelink_enabled ? 1 : 0
  name                    = "argocd-readonly-password"
  recovery_window_in_days = 0
  description             = "Password for ArgoCD readonly hyperspace user"
}

resource "aws_secretsmanager_secret_version" "argocd_readonly_password" {
  count         = local.argocd_privatelink_enabled ? 1 : 0
  secret_id     = aws_secretsmanager_secret.argocd_readonly_password[0].id
  secret_string = random_password.argocd_readonly[0].result
}

# Execute ArgoCD CLI setup and password update
resource "null_resource" "argocd_create_user" {
  count = local.argocd_privatelink_enabled ? 1 : 0
  provisioner "local-exec" {
    command = <<EOT
      echo "Getting ArgoCD admin password..."
      
      # Always assume the role to ensure consistent permissions
      CREDS=$(aws sts assume-role --role-arn arn:aws:iam::${var.aws_account_id}:role/${var.terraform_role} --role-session-name terraform-local-exec)
      if [ $? -ne 0 ]; then
        echo "Failed to assume role"
        exit 1
      fi
      
      # Set AWS credentials
      export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.Credentials.AccessKeyId')
      export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.Credentials.SecretAccessKey')
      export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.Credentials.SessionToken')
      
      # Verify AWS credentials
      if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo "Failed to verify AWS credentials"
        exit 1
      fi
      
      # Update kubeconfig
      aws eks update-kubeconfig --name ${local.cluster_name} --region ${var.aws_region}
      if [ $? -ne 0 ]; then
        echo "Failed to update kubeconfig"
        exit 1
      fi
      
      # Get current password
      CURRENT_HYPERSPACE_PASSWORD=$(kubectl -n argocd get secret argocd-secret -o jsonpath="{.data.accounts\\.hyperspace\\.password}" | base64 -d)
      if [ $? -ne 0 ]; then
        echo "Failed to get current password"
        exit 1
      fi
      
      NEW_PASSWORD="${random_password.argocd_readonly[count.index].result}"
      
      if [ "$CURRENT_HYPERSPACE_PASSWORD" = "$NEW_PASSWORD" ]; then
        echo "Current password matches desired password. No update needed."
        exit 0
      fi
      
      # Get ArgoCD admin password
      ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
      if [ $? -ne 0 ]; then
        echo "Failed to get ArgoCD admin password"
        exit 1
      fi
      
      # Try internal DNS first
      LOGIN_SUCCESS=0
      for i in {1..6}; do
        if argocd login argocd.${local.internal_domain_name} --username admin --password $ARGOCD_PASSWORD --insecure --plaintext --grpc-web >/dev/null 2>&1; then
          LOGIN_SUCCESS=1
          break
        else
          echo "Login attempt to internal DNS failed. Retrying..."
          sleep 10
        fi
      done
      
      if [ $LOGIN_SUCCESS -eq 0 ]; then
        echo "Internal DNS login failed after 1 minute. Trying port-forward..."
        kubectl -n argocd port-forward svc/argocd-server 8080:443 &
        PORT_FORWARD_PID=$!
        sleep 5
        LOGIN_SUCCESS=0
        for i in {1..6}; do
          if argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure --plaintext --grpc-web >/dev/null 2>&1; then
            LOGIN_SUCCESS=1
            break
          else
            echo "Port-forward login attempt failed. Retrying..."
            sleep 10
          fi
        done
        
        if [ $LOGIN_SUCCESS -eq 1 ]; then
          argocd account update-password \
            --account hyperspace \
            --current-password $ARGOCD_PASSWORD \
            --new-password $NEW_PASSWORD && echo "Hyperspace User password updated successfully!"
          kill $PORT_FORWARD_PID
          exit 0
        else
          echo "Port-forward login failed after all retries."
          kill $PORT_FORWARD_PID
          exit 1
        fi
      fi
    EOT
  }
  depends_on = [helm_release.argocd, data.aws_lb.argocd_privatelink_nlb[0]]
  triggers = {
    helm_release_id   = helm_release.argocd[count.index].id
    readonly_password = random_password.argocd_readonly[count.index].result
    timestamp         = timestamp()
  }
}