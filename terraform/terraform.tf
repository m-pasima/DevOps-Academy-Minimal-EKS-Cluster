locals {
  cluster_name = "teaching-eks-cluster"
  tags_common  = { Project = "teaching-eks" }
}

terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  backend "s3" {
    bucket         = ""  # Populated by workflow via secrets.TF_BACKEND_BUCKET
    key            = ""  # Populated by workflow via secrets.TF_BACKEND_KEY
    region         = ""  # Populated by workflow via secrets.AWS_REGION
    dynamodb_table = ""  # Populated by workflow via secrets.TF_BACKEND_TABLE
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}
