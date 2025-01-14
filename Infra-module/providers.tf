provider "aws" {
  region = var.aws_region
}

provider "tfe" {
  version = "~>0.62.0"
}