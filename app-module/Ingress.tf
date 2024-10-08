locals {
  ingress_config = {
    internal = {
      internal  = true
      scheme    = "internal"
      s3_prefix = "InternalALB"
    }
  }

  external_ingress_config = var.create_public_zone ? {
    external = {
      internal  = false
      scheme    = "internet-facing"
      s3_prefix = "ExternalALB"
    }
  } : {}

  combined_ingress_config = merge(local.ingress_config, local.external_ingress_config)
  common_ingress_annotations = {
    "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
    "alb.ingress.kubernetes.io/ssl-policy"       = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    "alb.ingress.kubernetes.io/target-type"      = "ip"
  }
}

resource "helm_release" "nginx-ingress" {
  for_each         = local.eks_exists ? local.combined_ingress_config : {}
  name             = "ingress-nginx-${each.key}"
  chart            = "ingress-nginx"
  version          = "~> 4.11.2"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  namespace        = "ingress"
  create_namespace = true
  wait             = true
  values = [<<EOF
controller:
  electionID: ${each.key}-controller-leader
  replicaCount: 2
  extraArgs:
    http-port: 8080
    https-port: 9443
  image:
    allowPrivilegeEscalation: false
  resources:
    requests:
      cpu: 100m      
      memory: 100Mi 
  autoscaling:
    enabled: "true"
    minReplicas: 2
    maxReplicas: 6
    targetCPUUtilizationPercentage: 50    
    targetMemoryUtilizationPercentage: 80 
    behavior:
      scaleDown:
        stabilizationWindowSeconds: 300  
        policies:
        - type: Percent
          value: 100
          periodSeconds: 15              
      scaleUp:
        stabilizationWindowSeconds: 60   
        policies:
        - type: Percent
          value: 100
          periodSeconds: 15              
        - type: Pods
          value: 4
          periodSeconds: 15              
        selectPolicy: Max               
  publishService:
    enabled: "true"
  metrics:
    enabled: "true"
  ingressClassByName: true
  ingressClassResource:
    name: nginx-${each.key}
    controllerValue: "k8s.io/nginx-${each.key}"
  config:
    client-max-body-size: "100m"
    use-forwarded-headers: "true"
    use-proxy-protocol: "false"
    compute-full-forwarded-for: "true"
  service:
    type: NodePort
    server-tokens: false
    externalTrafficPolicy: Local
    ports:
      http: 80
      https: 443
    targetPorts:
      http: 8080
      https: 9443
  containerPort:
    http: 8080
    https: 9443
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - ingress-nginx
          - key: app.kubernetes.io/instance
            operator: In
            values:
            - ingress-nginx-${each.key}
          - key: app.kubernetes.io/component
            operator: In
            values:
            - controller
        topologyKey: "kubernetes.io/hostname"
  EOF
  ]
  depends_on = [module.eks_blueprints_addons, module.acm]
}


resource "kubernetes_ingress_v1" "nginx_ingress" {
  for_each = local.eks_exists ? local.combined_ingress_config : {}
  metadata {
    name      = "${each.key}-ingress"
    namespace = "ingress"
    annotations = merge({
      "alb.ingress.kubernetes.io/certificate-arn"          = local.create_acm ? (each.key == "internal" ? module.acm["internal_acm"].acm_certificate_arn : module.acm["external_acm"].acm_certificate_arn) : (each.key == "internal" ? (var.internal_acm_arn != "" ? var.internal_acm_arn : "") : (var.external_acm_arn != "" ? var.external_acm_arn : ""))
      "alb.ingress.kubernetes.io/scheme"                   = "${each.value.scheme}"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=600, access_logs.s3.enabled=true, access_logs.s3.bucket=${local.s3_buckets["logs-ingress"].s3_bucket_id},access_logs.s3.prefix=${each.value.s3_prefix}"
      "alb.ingress.kubernetes.io/actions.ssl-redirect"     = (each.key == "internal" && module.acm["internal_acm"].acm_certificate_arn != "") || (each.key == "external" && module.acm["external_acm"].acm_certificate_arn != "") ? "{\"Type\": \"redirect\", \"RedirectConfig\": { \"Protocol\": \"HTTPS\", \"Port\": \"443\", \"StatusCode\": \"HTTP_301\"}}" : ""
      "alb.ingress.kubernetes.io/listen-ports"             = (each.key == "internal" && module.acm["internal_acm"].acm_certificate_arn != "") || (each.key == "external" && module.acm["external_acm"].acm_certificate_arn != "") ? "[{\"HTTP\": 80}, {\"HTTPS\":443}]" : "[{\"HTTP\": 80}]"
    }, local.common_ingress_annotations)
  }
  spec {
    ingress_class_name = "alb"
    default_backend {
      service {
        name = "ingress-nginx-${each.key}-controller"
        port {
          number = 80
        }
      }
    }
    rule {
      http {
        path {
          backend {
            service {
              name = "ssl-redirect"
              port {
                name = "use-annotation"
              }
            }
          }
          path = "/*"
        }
        path {
          backend {
            service {
              name = "ingress-nginx-${each.key}-controller"
              port {
                number = 80
              }
            }
          }
          path = "/*"
        }
      }
    }
  }
  depends_on = [helm_release.nginx-ingress]
}