# IAM Role for EKS Cluster
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

# Attach Policies to Cluster Role
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# IAM Policy for AWS Load Balancer Controller
data "http" "iam_policy_alb" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.project_name}-AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = data.http.iam_policy_alb.response_body
}

# IAM Role for AWS Load Balancer Controller with IRSA
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-AWSLoadBalancerControllerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com",
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

# Attach Policy to AWS Load Balancer Controller Role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# OIDC Provider for EKS
data "aws_eks_cluster" "cluster" {
  name       = aws_eks_cluster.this.name
  depends_on = [aws_eks_cluster.this]
}

# Compute OIDC provider thumbprint dynamically to avoid static/rotating values
data "tls_certificate" "eks" {
  url        = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  depends_on = [aws_eks_cluster.this]
}

resource "aws_iam_openid_connect_provider" "eks" {
  url            = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
  # Use the TLS certificate fingerprint from the OIDC issuer
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
}

# Security Group for EKS Cluster
resource "aws_security_group" "cluster" {
  name        = "${var.project_name}-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-cluster-sg" }
}

# Security Group for EKS Worker Nodes
resource "aws_security_group" "node" {
  name        = "${var.project_name}-node-sg"
  description = "EKS worker nodes"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-node-sg" }
}

# Security Group Rules
resource "aws_security_group_rule" "cluster_in_from_nodes_443" {
  type                     = "ingress"
  description              = "Nodes to control-plane API"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
}

resource "aws_security_group_rule" "node_in_from_cluster_10250" {
  type                     = "ingress"
  description              = "Control-plane to kubelet"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "node_in_from_cluster_ephemeral" {
  type                     = "ingress"
  description              = "Control-plane to nodes ephemeral"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "node_in_from_self_all" {
  type              = "ingress"
  description       = "Node to node all traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  self              = true
}

resource "aws_security_group_rule" "node_in_nodeports_optional" {
  count             = var.enable_nodeport_ingress ? 1 : 0
  type              = "ingress"
  description       = "NodePort range (optional)"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = var.nodeport_cidrs

  lifecycle {
    precondition {
      condition     = length(var.nodeport_cidrs) > 0
      error_message = "When enable_nodeport_ingress=true, you must provide at least one CIDR in var.nodeport_cidrs."
    }
  }
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
    subnet_ids              = [for k, v in aws_subnet.public : v.id]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  lifecycle {
    ignore_changes = [access_config[0].bootstrap_cluster_creator_admin_permissions]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController
  ]
}

# IAM Role for EKS Worker Nodes
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

# Attach Policies to Node Role
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

# Launch Template for Nodes
resource "aws_launch_template" "nodes" {
  name_prefix            = "${var.project_name}-ng-"
  update_default_version = true

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

# Spot Node Group
resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-spot"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [for k, v in aws_subnet.public : v.id]

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
    version = var.lt_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy
  ]
}

# On-Demand Node Group
resource "aws_eks_node_group" "on_demand" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-on-demand"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [for k, v in aws_subnet.public : v.id]

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
    version = var.lt_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy
  ]
}

# EKS Access Entry for Admin
resource "aws_eks_access_entry" "admin" {
  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = var.admin_principal_arn
  type              = "STANDARD"
}

# EKS Access Policy Association
resource "aws_eks_access_policy_association" "admin_cluster_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}
