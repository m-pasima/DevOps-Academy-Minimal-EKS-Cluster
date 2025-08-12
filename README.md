# Minimal EKS Cluster — DevOps Academy

This repository provisions a minimal EKS cluster ideal for teaching Kubernetes fundamentals: public subnets, a tiny node group, and cost-conscious architecture.

---

##  Usage Overview

1. **Prepare AWS backend** (S3 & DynamoDB) — use the Student Setup Guide.  
2. **Run Apply workflow** via GitHub Actions to deploy the cluster.  
3. **Connect locally**, test, and teach — instructions in the Student Setup Guide.

---

##  Student Setup Guide
All steps—from AWS console, IAM, GitHub secrets, local setup to connecting—are detailed here:

[Student Setup Guide](docs/STUDENT_SETUP_GUIDE.md)

> ⭐ Tip: Work through the guide **step-by-step** for your first deployment.

---

##  Workflow Overview

| Workflow        | What it does                          |
|-----------------|----------------------------------------|
| **Apply EKS**   | Deploys EKS cluster via Terraform |
| **Destroy EKS** | Tears down cluster to avoid unnecessary costs |

Review and run these under the **Actions** tab when you're ready to apply or destroy the setup.

---

##  After Apply: Common Commands

```bash
# Configure your kubeconfig for cluster access
aws eks update-kubeconfig --region eu-west-2 --name teaching-eks-cluster

# Verify nodes are Ready
kubectl get nodes -o wide

# (Optional) Deploy a test app
kubectl create deployment nginx-test --image=nginx
kubectl expose deployment nginx-test --type=LoadBalancer --port=80
kubectl get svc nginx-test
