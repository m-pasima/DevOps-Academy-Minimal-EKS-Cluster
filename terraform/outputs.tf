output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "efs_csi_addon_version" {
  description = "Version of the aws-efs-csi-driver add-on"
  value       = data.aws_eks_addon.efs_csi.addon_version
}
