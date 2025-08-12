provider "aws" {
  region = var.region
}

data "aws_partition" "current" {}
