# IAM
resource "aws_iam_policy" "policies" {
  for_each    = local.iam_policies
  name        = each.value.name
  path        = each.value.path
  description = each.value.description
  policy      = each.value.policy
}