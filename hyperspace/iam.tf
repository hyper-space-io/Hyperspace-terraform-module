# IAM
resource "aws_iam_policy" "policies" {
  for_each    = local.iam_policies
  name        = each.value.name
  path        = each.value.path
  description = each.value.description
  policy      = each.value.policy
}

# Create the KMS grant
resource "aws_kms_grant" "asg_grant" {
  name              = "asg-cross-account-grant"
  key_id            = data.aws_kms_key.by_alias.arn
  grantee_principal = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
  operations = [
    "Encrypt",
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "DescribeKey",
  ]
}