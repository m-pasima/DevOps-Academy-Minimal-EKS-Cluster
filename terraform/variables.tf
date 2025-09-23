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
