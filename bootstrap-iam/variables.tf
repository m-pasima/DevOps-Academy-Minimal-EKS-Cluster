variable "region"     { type = string, default = "eu-west-2" }
variable "role_name"  { type = string, default = "github-oidc-eks-admin" }
variable "github_org" { type = string } # e.g. "PassyOrg"
variable "repo_name"  { type = string } # e.g. "eks-teaching"
variable "branch"     { type = string, default = "main" }
