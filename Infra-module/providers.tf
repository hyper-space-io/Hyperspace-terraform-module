terraform {
  required_providers {
    tfe = {
      source = "hashicorp/tfe"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" { region = var.aws_region }

provider "tfe" {}