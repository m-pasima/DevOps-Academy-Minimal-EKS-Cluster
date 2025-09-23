variable "project_name" {
  type        = string
  description = "Name prefix for resources"
  default     = "teaching-eks"
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-2"
}

variable "cluster_version" {
  type        = string
  description = "EKS control plane version"
  default     = "1.29"
}

# Spot node group sizing (Group A)
variable "spot_instance_types" {
  type        = list(string)
  description = "Instance types for the SPOT group"
  default     = ["t3.small"]
}
variable "spot_min_size"     { type = number, default = 1 }
variable "spot_desired_size" { type = number, default = 1 }
variable "spot_max_size"     { type = number, default = 1 }

# On-demand node group sizing (Group B)
variable "od_instance_types" {
  type        = list(string)
  description = "Instance types for the ON_DEMAND group"
  default     = ["t3.small"]
}
variable "od_min_size"     { type = number, default = 1 }
variable "od_desired_size" { type = number, default = 1 }
variable "od_max_size"     { type = number, default = 1 }

# Access management (EKS)
variable "admin_principal_arn" {
  type        = string
  description = "IAM user/role ARN to grant cluster-admin via EKS Access Entry"
}

# NodePort exposure knobs
variable "enable_nodeport_ingress" {
  type        = bool
  description = "Whether to allow inbound NodePort range (30000-32767/tcp) to worker nodes."
  default     = false
}

variable "nodeport_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach NodePort range (used only when enable_nodeport_ingress=true)."
  default     = ["0.0.0.0/0"]

  # Validation can reference only THIS variable.
  validation {
    condition     = alltrue([for c in var.nodeport_cidrs : can(cidrhost(c, 0))])
    error_message = "nodeport_cidrs must be a list of valid CIDR blocks, e.g. [\"203.0.113.10/32\"]."
  }
}

# Launch Template version selection
variable "lt_version" {
  type        = string
  description = "Launch Template version for EKS node groups (\"$Latest\" or a specific version string like \"3\")."
  default     = "$Latest"
}
