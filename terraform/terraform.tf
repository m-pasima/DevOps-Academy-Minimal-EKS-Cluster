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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name]
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
