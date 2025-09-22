variable "project_name" {
  type        = string
  default     = "teaching-eks"
  description = "Name prefix for resources"
}

variable "region" {
  type        = string
  default     = "eu-west-2"
  description = "AWS region"
}

variable "cluster_version" {
  type        = string
  default     = "1.29"
  description = "EKS control plane version"
}

# Spot node group sizing (group A)
variable "spot_instance_types" {
  type        = list(string)
  default     = ["t3.small"]
  description = "Instance types for the SPOT group"
}

variable "spot_min_size" {
  type    = number
  default = 1
}

variable "spot_desired_size" {
  type    = number
  default = 1
}

variable "spot_max_size" {
  type    = number
  default = 1
}

# On-demand node group sizing (group B)
variable "od_instance_types" {
  type        = list(string)
  default     = ["t3.small"]
  description = "Instance types for the ON_DEMAND group"
}

variable "od_min_size" {
  type    = number
  default = 1
}

variable "od_desired_size" {
  type    = number
  default = 1
}

variable "od_max_size" {
  type    = number
  default = 1
}

# Who gets cluster-admin via EKS Access Entry
variable "admin_principal_arn" {
  type        = string
  description = "IAM user/role ARN to grant cluster-admin"
}
