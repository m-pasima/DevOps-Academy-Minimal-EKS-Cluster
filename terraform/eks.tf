############################################
# EKS Control Plane + Two Node Groups (FIXED)
############################################

# Cluster IAM role
resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Recommended for SG-for-Pods / ENI mgmt
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# Control-plane Security Group
resource "aws_security_group" "cluster" {
  name        = "${var.project_name}-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = aws_vpc.this.id

  # API access (tighten to your office IP if desired)
  ingress {
    description = "K8s API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-cluster-sg" }
}

# Node Security Group (we will attach this via Launch Template)
resource "aws_security_group" "node" {
  name        = "${var.project_name}-node-sg"
  description = "EKS worker nodes"
  vpc_id      = aws_vpc.this.id

  # Outbound to internet for image pulls, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-node-sg" }
}

# REQUIRED cross-SG rules: control-plane <-> nodes
# Nodes -> Control-plane (API server)
resource "aws_security_group_rule" "cluster_in_from_nodes_443" {
  type                     = "ingress"
  description              = "Nodes to control-plane API"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
}

# Control-plane -> Nodes (kubelet)
resource "aws_security_group_rule" "node_in_from_cluster_10250" {
  type                     = "ingress"
  description              = "Control-plane to kubelet"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
}

# Control-plane -> Nodes (ephemeral for health checks, etc.)
resource "aws_security_group_rule" "node_in_from_cluster_ephemeral" {
  type                     = "ingress"
  description              = "Control-plane to nodes ephemeral"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
}

# Nodes <-> Nodes (pod-to-pod, CNI, etc.)
resource "aws_security_group_rule" "node_in_from_self_all" {
  type              = "ingress"
  description       = "Node to node all traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  self              = true
}

# Optional: External access to NodePorts (prefer ALB/NLB instead)

resource "aws_security_group_rule" "node_in_nodeports_optional" {
  type              = "ingress"
  description       = "NodePort range (optional)"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# EKS Cluster
resource "aws_eks_cluster" "this" {
  name     = "${var.project_name}-cluster"
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    endpoint_public_access  = true
    endpoint_private_access = false
    security_group_ids      = [aws_security_group.cluster.id]
    subnet_ids              = [for s in aws_subnet.public : s.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController
  ]
}

# Node IAM role
resource "aws_iam_role" "node" {
  name = "${var.project_name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Launch Template to ATTACH OUR NODE SG to managed node groups
resource "aws_launch_template" "nodes" {
  name_prefix            = "${var.project_name}-ng-"
  update_default_version = true

  # We don't set AMI or user_data: EKS MNG will inject its own AMI/settings.
  # We only want to control the NIC SGs.
  network_interfaces {
    security_groups = [aws_security_group.node.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-node"
    }
  }
}

# Managed Node Group (SPOT)
resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-spot"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [for s in aws_subnet.public : s.id]

  capacity_type  = "SPOT"
  instance_types = var.spot_instance_types

  scaling_config {
    desired_size = var.spot_desired_size
    max_size     = var.spot_max_size
    min_size     = var.spot_min_size
  }

  labels = { pool = "spot" }

  update_config { max_unavailable = 1 }

  launch_template {
    id      = aws_launch_template.nodes.id
    version = "$Latest"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy
  ]
}

# Managed Node Group (ON_DEMAND)
resource "aws_eks_node_group" "on_demand" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-on-demand"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [for s in aws_subnet.public : s.id]

  capacity_type  = "ON_DEMAND"
  instance_types = var.od_instance_types

  scaling_config {
    desired_size = var.od_desired_size
    max_size     = var.od_max_size
    min_size     = var.od_min_size
  }

  labels = { pool = "on-demand" }

  update_config { max_unavailable = 1 }

  launch_template {
    id      = aws_launch_template.nodes.id
    version = "$Latest"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy
  ]
}

# Modern RBAC: EKS Access Entry + ClusterAdminPolicy
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_cluster_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_principal_arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
# END OF FILE

