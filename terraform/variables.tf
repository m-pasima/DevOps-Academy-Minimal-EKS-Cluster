variable "project_name"    { type = string, default = "teaching-eks" }
variable "region"          { type = string, default = "eu-west-2" }
variable "cluster_version" { type = string, default = "1.29" }

# Spot node group sizing (group A)
variable "spot_instance_types" { type = list(string), default = ["t3.small"] }
variable "spot_min_size"       { type = number, default = 1 }
variable "spot_desired_size"   { type = number, default = 1 }
variable "spot_max_size"       { type = number, default = 1 }

# On-demand node group sizing (group B)
variable "od_instance_types"   { type = list(string), default = ["t3.small"] }
variable "od_min_size"         { type = number, default = 1 }
variable "od_desired_size"     { type = number, default = 1 }
variable "od_max_size"         { type = number, default = 1 }
