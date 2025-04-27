resource "helm_release" "argocd" {
  count            = var.create_eks && var.enable_argocd ? 1 : 0
  chart            = "argo-cd"
  namespace        = "argocd"
  name             = "argocd"
  version          = "7.7.11"
  depends_on       = [helm_release.nginx-ingress]
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
          "policy.default" = "${var.argocd_rbac_policy_default}"
          "policy.csv"     = join("\n", local.default_argocd_rbac_policy_rules)
        }
        cm = {
          "exec.enabled"           = "false"
          "timeout.reconciliation" = "5s"
          "accounts.hyperspace"    = "login"
          "dex.config" = yamlencode({
            connectors = local.dex_connectors
          })
        }
        credentialTemplates = local.argocd_credential_templates
      }
      server = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-internal"               = "true"
            "service.beta.kubernetes.io/aws-load-balancer-type"                   = "nlb-ip"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"                 = "internal"
            "service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy" = "ELBSecurityPolicy-TLS13-1-2-2021-06"
          }
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

resource "random_password" "argocd_readonly" {
  count  = var.create_eks && var.enable_argocd ? 1 : 0
  length = 16
}

resource "aws_secretsmanager_secret" "argocd_readonly_password" {
  count       = var.create_eks && var.enable_argocd ? 1 : 0
  name        = "argocd-readonly-password"
  description = "Password for ArgoCD readonly hyperspace user"
}

resource "aws_secretsmanager_secret_version" "argocd_readonly_password" {
  count         = var.create_eks && var.enable_argocd ? 1 : 0
  secret_id     = aws_secretsmanager_secret.argocd_readonly_password[0].id
  secret_string = random_password.argocd_readonly[0].result
}

# Execute ArgoCD CLI setup and password update
resource "null_resource" "argocd_setup" {
  count = var.create_eks && var.enable_argocd ? 1 : 0
  provisioner "local-exec" {
    command = <<-EOT
      echo "Getting ArgoCD admin password..."
      aws eks update-kubeconfig --name ${local.cluster_name} --region ${var.aws_region}
      ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

      echo "Logging in to ArgoCD..."
      until argocd login argocd.${local.internal_domain_name} --username admin --password $ARGOCD_PASSWORD --insecure --grpc-web; do
        echo "Login attempt failed. Waiting 10 seconds before retrying..."
        sleep 10
      done
      
      echo "Successfully logged in to ArgoCD!"
      echo "Updating hyperspace user password..."
      argocd account update-password \
        --account hyperspace \
        --current-password $ARGOCD_PASSWORD \
        --new-password ${random_password.argocd_readonly[count.index].result}
      echo "Hyperspace User password updated successfully!"
    EOT
  }
  depends_on = [helm_release.argocd, data.aws_lb.argocd_privatelink_nlb[0]]
  triggers = {
    helm_release_id   = helm_release.argocd[count.index].id
    readonly_password = random_password.argocd_readonly[count.index].result
  }
}