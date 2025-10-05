############################################
# EFS CSI Driver (IRSA + Addon) and Storage
############################################

# IAM role for the EFS CSI controller service account
resource "aws_iam_role" "efs_csi" {
  name = "AmazonEKS_EFS_CSI_DriverRole"

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
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:kube-system:efs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-EFSCSIDriverRole"
  }
}

# Attach the AWS-managed policy required by the EFS CSI driver
resource "aws_iam_role_policy_attachment" "efs_csi_policy" {
  role       = aws_iam_role.efs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

# EKS Add-on for AWS EFS CSI driver
resource "aws_eks_addon" "efs_csi" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-efs-csi-driver"
  service_account_role_arn = aws_iam_role.efs_csi.arn

  # Resolve potential Helm/managed resource conflicts gracefully
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_iam_role_policy_attachment.efs_csi_policy,
    aws_iam_openid_connect_provider.eks,
    aws_eks_cluster.this
  ]
}

# Read back the add-on to expose status for outputs
data "aws_eks_addon" "efs_csi" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "aws-efs-csi-driver"
  depends_on   = [aws_eks_addon.efs_csi]
}

########################
# EFS storage resources
########################

# Security group for EFS to allow NFS from worker nodes
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Allow NFS from EKS worker nodes"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-efs-sg" }
}

resource "aws_security_group_rule" "efs_in_from_nodes_2049" {
  type                     = "ingress"
  description              = "Allow NFS from worker nodes"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = aws_security_group.node.id
}

# EFS File System
resource "aws_efs_file_system" "this" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "${var.project_name}-efs"
  }
}

# Mount targets in each public subnet where nodes run
resource "aws_efs_mount_target" "this" {
  for_each = aws_subnet.public

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value.id
  security_groups = [aws_security_group.efs.id]
}
