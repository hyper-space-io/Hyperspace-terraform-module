# Karpenter module for provisioning and managing compute resources in EKS
module "karpenter" {
  count  = var.enable_karpenter ? 1 : 0
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  version                         = "20.36.0"
  cluster_name                    = module.eks.cluster_name
  enable_irsa                     = true # Enable IAM Roles for Service Accounts
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]
  create_node_iam_role            = true # Create IAM role for Karpenter nodes
  create_instance_profile         = true # Create instance profile for nodes
  iam_role_policies = {
    "KarpenterSpotSLRPolicy" = aws_iam_policy.karpenter_controller_spot_slr_policy[0].arn
  }
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # Allow SSM access to nodes
    AmazonEBSCSIDriverPolicy     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" # Allow EBS CSI driver access
  }
  tags       = var.tags
  depends_on = [module.eks]
}

# IAM policy allowing Karpenter to create EC2 Spot Service Linked Role
resource "aws_iam_policy" "karpenter_controller_spot_slr_policy" {
  count       = var.enable_karpenter ? 1 : 0
  name        = "karpenter_controller_spot_slr_policy_${var.environment}"
  description = "Policy for Karpenter controller to create EC2 Spot Service Linked Role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole",
        Resource = "arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot*",
        Condition = {
          StringLike = {
            "iam:AWSServiceName" = "spot.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Install Karpenter CRDs (Custom Resource Definitions)
resource "helm_release" "karpenter_crd" {
  count            = var.enable_karpenter ? 1 : 0
  provider         = helm.karpenter
  namespace        = "karpenter"
  name             = "karpenter-crd"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = "1.5.0"
  create_namespace = true
}

# Install Karpenter controller
resource "helm_release" "karpenter" {
  count            = var.enable_karpenter ? 1 : 0
  provider         = helm.karpenter
  namespace        = "karpenter"
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.5.0"
  depends_on       = [helm_release.karpenter_crd, module.karpenter]
  wait             = true # Wait for the release to be deployed
  create_namespace = true
  values = [
    yamlencode({
      replicas  = var.karpenter_controller_config.replicas
      dnsPolicy = "Default"
      serviceAccount = {
        annotations = {
          # Attach IAM role to Karpenter service account
          "eks.amazonaws.com/role-arn" = module.karpenter[0].iam_role_arn
        }
      }
      controller = {
        env = [
          {
            name  = "AWS_REGION"
            value = var.aws_region
          }
        ]
        resources = var.karpenter_controller_config.resources # CPU/memory requests and limits
      }
      settings = {
        clusterName       = module.eks.cluster_name
        clusterEndpoint   = module.eks.cluster_endpoint
        interruptionQueue = module.karpenter[0].queue_name # SQS queue for spot interruption handling
        featureGates      = var.karpenter_controller_config.feature_gates
      }
      # Allow Karpenter to run on Fargate if needed
      tolerations = var.karpenter_controller_config.fargate_enabled ? [
        {
          key      = "eks.amazonaws.com/compute-type"
          operator = "Equal"
          value    = "fargate"
          effect   = "NoSchedule"
        }
      ] : []
      nodeSelector = var.karpenter_controller_config.fargate_enabled ? {
        "eks.amazonaws.com/compute-type" = "fargate"
      } : {}
    })
  ]
}

resource "helm_release" "karpenter-manifest" {
  count            = var.enable_karpenter ? 1 : 0
  namespace        = "karpenter"
  name             = "karpenter-manifests"
  chart            = "${path.module}/karpenter-manifests"
  cleanup_on_fail  = true
  create_namespace = true
  values = [<<EOF
nodeClass:
    role: ${module.karpenter[0].node_iam_role_arn}
    discovery: ${module.eks.cluster_name}
dataNode:
  ami: ${data.aws_ami.fpga.id}
  kmsKeyId: ${data.aws_kms_key.by_alias.arn}
EOF
  ]
  depends_on = [module.karpenter, helm_release.karpenter, helm_release.karpenter_crd]
  set {
    name  = "force_update"
    value = timestamp()
  }

}