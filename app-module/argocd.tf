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
                type = connector.type
                id   = connector.id
                name = connector.name
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
            service.beta.kubernetes.io/aws-load-balancer-internal = "true"
            service.beta.kubernetes.io/aws-load-balancer-type = "nlb-ip"
            service.beta.kubernetes.io/aws-load-balancer-scheme = "internal"
            service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
          }
        }
        autoscaling = {
          enabled     = true
          minReplicas = "1"
        }
        extraArgs = ["--insecure"]
        ingress = {
          enabled          = false
          # ingressClassName = "nginx-internal"
          # hosts = [
          #   "argocd.${local.internal_domain_name}"
          # ]
          # https = false
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

# locals {
#   dex_config = length(var.dex_connectors) > 0 ? {
#     connectors = [
#       for connector in jsondecode(var.dex_connectors) : {
#         type = connector.type
#         id   = connector.id
#         name = connector.name
#         config = {
#           for key, value in connector.config :
#           key => key == "orgs" ? [
#             for org in split(",", value) : trim(org, " ")
#           ] : value
#         }
#       }
#     ]
#   } : {}

#   argocd_values = yamlencode({
#     dex = {
#       enabled = length(var.dex_connectors) > 0
#     }
#     configs = {
#       cm = {
#         url = "https://argocd.${local.internal_domain_name}"
#         "dex.config" = yamlencode(local.dex_config)
#       }
#       rbac = {
#         "policy.default" = var.argocd_rbac_policy_default
#         "policy.csv"     = try(join("\n", var.argocd_rbac_policy_rules), "")
#       }
#     }
#     "redis-ha" = var.enable_ha_argocd ? {
#       enabled = true
#     } : null
#     controller = var.enable_ha_argocd ? {
#       replicas = 1
#     } : null
#     server = merge({
#       extraArgs = ["--insecure"]
#       ingress = {
#         enabled           = local.eks_exists
#         ingressClassName = "nginx-internal"
#         hostname         = "argocd.${local.internal_domain_name}"
#         https            = false
#       }
#     }, var.enable_ha_argocd ? {
#       autoscaling = {
#         enabled     = true
#         minReplicas = 2
#       }
#     } : {
#       autoscaling = {
#         enabled = false
#         minReplicas = 1
#       }
#     })
#     repoServer = var.enable_ha_argocd ? {
#       autoscaling = {
#         enabled     = true
#         minReplicas = 2
#       }
#     } : null
#     applicationSet = var.enable_ha_argocd ? {
#       replicas = 2
#     } : null
#   })
# }

# resource "helm_release" "argocd" {
#   count            = var.enable_argocd ? 1 : 0
#   chart            = "argo-cd"
#   version          = "~> 7.7.3"
#   name             = "argocd"
#   namespace        = "argocd"
#   create_namespace = true
#   repository       = "https://argoproj.github.io/argo-helm"
#   values           = [local.argocd_values]
#   cleanup_on_fail  = true
#   depends_on       = [module.eks, module.iam_iam-assumable-role-with-oidc]
# }