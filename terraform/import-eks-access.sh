#!/bin/bash

set -euo pipefail

# Variables (customize as needed)
CLUSTER_NAME="teaching-eks-cluster"
ADMIN_ARN="arn:aws:iam::084375555179:user/***-user"  # Replace *** with your IAM username
POLICY_ARN="arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

# Check and import aws_eks_access_entry.admin
if ! terraform state list | grep -q aws_eks_access_entry.admin; then
  echo "Importing aws_eks_access_entry.admin..."
  terraform import aws_eks_access_entry.admin "${CLUSTER_NAME}:${ADMIN_ARN}"
else
  echo "aws_eks_access_entry.admin already in state – skipping import."
fi

# Check and import aws_eks_access_policy_association.admin_cluster_admin
if ! terraform state list | grep -q aws_eks_access_policy_association.admin_cluster_admin; then
  echo "Importing aws_eks_access_policy_association.admin_cluster_admin..."
  terraform import aws_eks_access_policy_association.admin_cluster_admin "${CLUSTER_NAME}#${ADMIN_ARN}#${POLICY_ARN}"
else
  echo "aws_eks_access_policy_association.admin_cluster_admin already in state – skipping import."
fi

echo "Import process complete."
