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

# IAM principal to grant cluster-admin via EKS Access Entry
variable "admin_principal_arn" {
  type        = string
  description = "IAM user/role ARN to grant cluster-admin"
}
# Open NodePort range on the node security group? Prefer 'false' and front services with an ALB/NLB.
variable "enable_nodeport_ingress" {
  type        = bool
  description = "Whether to allow inbound NodePort range (30000-32767/tcp) to worker nodes."
  default     = false
}

# If you do enable NodePort ingress, restrict who can hit it. Default is wide open; override in tf_vars for safety.
variable "nodeport_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach NodePort range. Only used when enable_nodeport_ingress=true."
  default     = ["0.0.0.0/0"]

  # Optional guard to avoid empty list when the feature is enabled
  validation {
    condition     = (var.enable_nodeport_ingress == false) || (length(var.nodeport_cidrs) > 0)
    error_message = "When enable_nodeport_ingress=true, nodeport_cidrs cannot be empty."
  }
}

# Version selector for the launch template used by the managed node groups.
# Using "$Latest" tracks the latest default version of the LT. Pin to a number (e.g., "3") to freeze it.
variable "lt_version" {
  type        = string
  description = "Launch Template version to use for EKS node groups (\"$Latest\" or a specific version number as a string)."
  default     = "$Latest"
}
