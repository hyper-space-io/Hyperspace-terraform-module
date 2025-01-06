provider "aws" {
  region = var.aws_region
}

# terraform {
#   cloud {
#     organization = "Hyperspace_project"
#     workspaces {
#       name = "Infra-module"
#     }
#   }
# }