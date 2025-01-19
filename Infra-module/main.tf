# IAM
resource "aws_iam_policy" "policies" {
  for_each    = local.iam_policies
  name        = each.value.name
  path        = each.value.path
  description = each.value.description
  policy      = each.value.policy
}

module "iam_iam-assumable-role-with-oidc" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 5.48.0"
  for_each                      = { for k, v in local.iam_policies : k => v if lookup(v, "create_assumable_role", false) == true }
  create_role                   = true
  role_name                     = each.value.name
  provider_url                  = module.eks.cluster_oidc_issuer_url
  role_policy_arns              = [aws_iam_policy.policies["${each.key}"].arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${each.value.sa_namespace}:${each.key}"]
}

module "boto3_irsa" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  for_each  = { for k, v in local.iam_policies : k => v if lookup(v, "create_cluster_wide_role", false) == true }
  role_name = each.value.name
  role_policy_arns = {
    policy = aws_iam_policy.policies["${each.key}"].arn
  }
  assume_role_condition_test = "StringLike"
  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["*:*"]
    }
  }
  depends_on = [module.eks, aws_iam_policy.policies]
}