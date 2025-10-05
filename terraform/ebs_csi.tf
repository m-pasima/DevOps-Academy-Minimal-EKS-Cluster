###############################
# EBS CSI Driver (IRSA + Addon)
###############################

# IAM role for the EBS CSI controller service account
# Matches the name used in common docs/CLI examples
resource "aws_iam_role" "ebs_csi_controller" {
  name = "AmazonEKS_EBS_CSI_DriverRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" : "sts.amazonaws.com",
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-EBSCSIDriverRole"
  }
}

# Attach the AWS-managed policy required by the EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_controller_policy" {
  role       = aws_iam_role.ebs_csi_controller.name
  # The EBS CSI driver AWS-managed policy lives under the service-role path
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# EKS Add-on for AWS EBS CSI driver
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  # Let AWS manage the version unless you need to pin it explicitly
  # addon_version          = ""
  service_account_role_arn = aws_iam_role.ebs_csi_controller.arn

  # Resolve potential Helm/managed resource conflicts gracefully
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_controller_policy,
    aws_iam_openid_connect_provider.eks,
    aws_eks_cluster.this
  ]
}
