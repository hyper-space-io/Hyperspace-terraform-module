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
  for_each         = var.create_eks ? local.combined_ingress_config : {}
  name             = "ingress-nginx-${each.key}"
  chart            = "ingress-nginx"
  version          = "~> 4.11.2"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  namespace        = "ingress"
  create_namespace = true
  wait             = true
  cleanup_on_fail  = true
  timeout          = 600
  values = [<<EOF
controller:
  electionID: ${each.key}-controller-leader
  replicaCount: 1
  extraArgs:
    http-port: 8080
    https-port: 9443
  image:
    allowPrivilegeEscalation: false
  resources:
    requests:
      cpu: 100m      
      memory: 256Mi 
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 6
    targetCPUUtilizationPercentage: 75    
    targetMemoryUtilizationPercentage: 75 
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
    enabled: true
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: kube-prometheus-stack
      namespace: ingress
      scrapeInterval: 30s
    port: 10254
    service:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "10254"
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
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
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
  depends_on = [module.eks_blueprints_addons, module.external_acm, module.internal_acm, module.eks, helm_release.kube_prometheus_stack]
}

resource "kubernetes_ingress_v1" "nginx_ingress" {
  for_each = var.create_eks ? local.combined_ingress_config : {}
  metadata {
    name      = "${each.key}-ingress"
    namespace = "ingress"
    annotations = merge({
      "alb.ingress.kubernetes.io/certificate-arn"          = (each.key == "internal" && length(module.internal_acm) > 0) || (each.key == "external" && length(module.external_acm) > 0) ? (each.key == "internal" ? module.internal_acm[0].acm_certificate_arn : module.external_acm[0].acm_certificate_arn) : ""
      "alb.ingress.kubernetes.io/scheme"                   = each.value.scheme
      "alb.ingress.kubernetes.io/tags"                     = "Domain=${each.key}"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=600, access_logs.s3.enabled=true, access_logs.s3.bucket=${local.s3_bucket_names["logs-ingress"]},access_logs.s3.prefix=${each.value.s3_prefix}"
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = (each.key == "internal" && length(module.internal_acm) > 0 && module.internal_acm[0].acm_certificate_arn != "") || (each.key == "external" && var.create_public_zone && var.domain_name != "") ? jsonencode({
        Type = "redirect"
        RedirectConfig = {
          Protocol   = "HTTPS"
          Port       = "443"
          StatusCode = "HTTP_301"
        }
      }) : ""
      "alb.ingress.kubernetes.io/listen-ports" = (each.key == "internal" && length(module.internal_acm) > 0 && module.internal_acm[0].acm_certificate_arn != "") || (each.key == "external" && var.create_public_zone && var.domain_name != "") ? jsonencode([
        { HTTP = 80 },
        { HTTPS = 443 }
      ]) : jsonencode([{ HTTP = 80 }])
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
  depends_on = [helm_release.nginx-ingress, module.eks]
}

resource "time_sleep" "wait_for_internal_ingress" {
  count           = var.create_eks ? 1 : 0
  create_duration = "300s"
  depends_on      = [kubernetes_ingress_v1.nginx_ingress["internal"]]
}

resource "time_sleep" "wait_for_external_ingress" {
  count           = var.create_eks && var.create_public_zone ? 1 : 0
  create_duration = "300s"
  depends_on      = [kubernetes_ingress_v1.nginx_ingress["external"]]
}