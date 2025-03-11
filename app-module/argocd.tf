resource "helm_release" "argocd" {
  count            = var.create_eks ? 1 : 0
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
          "policy.csv"     = try(join("\n", var.argocd_rbac_policy_rules), "")
        }
        cm = {
          "exec.enabled"           = "true"
          "timeout.reconciliation" = "5s"
          "dex.config" = yamlencode({
            connectors = [
              for connector in jsondecode(var.dex_connectors) : {
                type   = connector.type
                id     = connector.id
                name   = connector.name
                config = connector.config
              }
            ]
          })
        }
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
          enabled          = false
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

resource "kubernetes_config_map" "argocd_cm" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name      = "argocd-cm-${var.environment}"
    namespace = "argocd"
    labels = {
      "app.kubernetes.io/name"    = "argocd-cm-${var.environment}"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    "accounts.hyperspace"         = "login"
    "accounts.hyperspace.enabled" = "true"
  }

  depends_on = [helm_release.argocd]
}
