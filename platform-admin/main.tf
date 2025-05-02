resource "aws_iam_role" "platformAdmin" {
  name = "PlatformAdmin"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {}
        }
    ]
}
EOF

  tags = {
    Terraform = "True"
  }
}

resource "aws_iam_role_policy_attachment" "adminAttach" {
  role       = aws_iam_role.platformAdmin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "aws_caller_identity" "current" {}

provider "aws" {
  region = "eu-west-2"
}

provider "random" {}
