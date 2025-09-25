resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2" # Check for the latest version

  set {
    name  = "clusterName"
    value = aws_eks_cluster.this.name
  }

  # Use IP targets by default (recommended)
  set {
    name  = "defaultTargetType"
    value = "ip"
  }

  set {
    name  = "region"
    value = var.region # Use variable for consistency
  }

  set {
    name  = "vpcId"
    value = aws_vpc.this.id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role_policy_attachment.aws_load_balancer_controller_attach
  ]
}
