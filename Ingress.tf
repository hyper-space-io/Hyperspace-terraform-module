locals {
  ingress_config = {
    internal = {
      internal  = true
      scheme    = "internal"
      s3_prefix = "InternalNLB"
    }
  }

  external_ingress_config = local.create_external_lb ? {
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
        service.beta.kubernetes.io/aws-load-balancer-type: "${each.value.internal ? "nlb-ip" : "external"}"
        service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
        service.beta.kubernetes.io/aws-load-balancer-internal: "${each.value.internal ? "true" : "false"}"
        service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${each.key == "internal" ? module.internal_acm[0].acm_certificate_arn : module.external_acm[0].acm_certificate_arn}"
        service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
        service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"
        service.beta.kubernetes.io/aws-load-balancer-attributes: load_balancing.cross_zone.enabled=true
        service.beta.kubernetes.io/aws-load-balancer-manage-backend-security-group-rules: "true"
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/healthz"
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "8080"
        service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: "scheme=${each.value.scheme}"
        service.beta.kubernetes.io/aws-load-balancer-access-log-enabled: "true"
        service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name: "${local.s3_bucket_names["logs-ingress"]}"
        service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-prefix: "${each.value.s3_prefix}"
      prometheus.io/scrape: "true"
      prometheus.io/port: "10254"
  ingressClassByName: true
  ingressClassResource:
    name: nginx-${each.key}
    controllerValue: "k8s.io/nginx-${each.key}"
  config:
    client-max-body-size: "100m"
    use-forwarded-headers: "false"
    compute-full-forwarded-for: "false"
    use-proxy-protocol: "true"
    ssl-redirect: "false"
  service:
    type: LoadBalancer
    server-tokens: false
    externalTrafficPolicy: Local
    ports:
      http: 80
      https: 443
    targetPorts:
      http: 8080
      https: 8080
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
  depends_on = [module.eks_blueprints_addons, module.external_acm, module.internal_acm, module.eks]
}
resource "kubernetes_ingress_v1" "nginx_ingress" {
  for_each = var.create_eks ? local.combined_ingress_config : {}
  metadata {
    name      = "${each.key}-ingress"
    namespace = "ingress"
  }
  spec {
    ingress_class_name = "nginx-${each.key}"
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
          path = "/"
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
          path = "/"
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
  count           = var.create_eks && local.create_external_lb ? 1 : 0
  create_duration = "300s"
  depends_on      = [kubernetes_ingress_v1.nginx_ingress["external"]]
}
