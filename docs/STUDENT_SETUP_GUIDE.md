## Student Setup Guide — Minimal EKS Cluster

This guide helps you set up everything needed to deploy and connect to the Minimal EKS Cluster without committing any secrets.

---

## 1) Create S3 Bucket for Terraform State

1. Log in to the AWS Console.
2. Go to S3 → Create bucket.
3. Fill in:
   - Bucket name: `eks-teaching-tfstate-YOURNAME`
   - Region: `eu-west-2` (or as provided by instructor)
4. Uncheck “Block all public access”.
5. Leave other settings default → Create bucket.

---

## 2) Create DynamoDB Table for State Locking

1. Go to DynamoDB → Create table.
2. Table name: `eks-teaching-tflock`
3. Partition key: `LockID` (String)
4. Leave other settings default → Create table.

---

## 3) Create IAM User for Terraform

1. Go to IAM → Users → Add users.
2. Username: `eks-terraform-user`
3. Select Access key - Programmatic access.
4. Attach policies (teaching example):
   - AmazonEKSClusterPolicy
   - AmazonEKSWorkerNodePolicy
   - AmazonEC2FullAccess
   - AmazonS3FullAccess
   - AmazonDynamoDBFullAccess
   - IAMFullAccess
5. Create the user and download the Access Key ID and Secret Access Key.

---

## 4) Store AWS Credentials in GitHub Secrets (for CI/CD)

1. In your GitHub repository: Settings → Secrets and variables → Actions.
2. Add these repository secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION` → `eu-west-2` (or your region)
   - `TF_BACKEND_BUCKET` → your S3 bucket name
   - `TF_BACKEND_TABLE` → `eks-teaching-tflock`
   - `TF_BACKEND_KEY` → `eks/teaching-eks-cluster/terraform/terraform.tfstate`

Note: Never commit AWS keys or local tfvars. The root `.gitignore` already ignores `*.tfvars`, `*.tfstate`, and `.terraform/`.

---

## 5) Install AWS CLI

- Windows: install AWS CLI v2 MSI, then `aws --version`
- macOS: `brew install awscli && aws --version`
- Linux: `curl -o awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && unzip awscliv2.zip && sudo ./aws/install && aws --version`

---

## 6) Install kubectl

- Windows: `choco install kubernetes-cli && kubectl version --client`
- macOS: `brew install kubectl && kubectl version --client`
- Linux: `curl -o kubectl https://amazon-eks.s3.amazonaws.com/1.29.0/2023-11-14/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/ && kubectl version --client`

---

## 7) Local Setup (run from your machine)

1) Clone the repo and go to Terraform dir:
- `git clone https://github.com/m-pasima/DevOps-Academy-Minimal-EKS-Cluster.git`
- `cd DevOps-Academy-Minimal-EKS-Cluster/terraform`

2) Configure AWS credentials (`aws configure`), enter:
- AWS Access Key ID → from IAM user
- AWS Secret Access Key → from IAM user
- Default region → `eu-west-2`
- Output format → `json` (or leave blank)

3) Create your local variables file from the example (git‑ignored):
- `cp terraform.tfvars.example terraform.tfvars`

4) Edit `terraform.tfvars` and set your admin principal ARN:
- `admin_principal_arn = "arn:aws:iam::<ACCOUNT_ID>:user/eks-admin-user"`
- Tip: Use your current caller as admin: `export TF_VAR_admin_principal_arn=$(aws sts get-caller-identity --query Arn --output text)`

5) Initialize the backend/providers:
- `terraform init -backend-config=backend.tfvars -reconfigure`

6) Plan and apply:
- `terraform plan  -var-file="terraform.tfvars"`
- `terraform apply -var-file="terraform.tfvars"`

7) Prevent committing secrets (recommended)
- Enable repo hooks: `git config core.hooksPath .githooks`
- The pre-commit hook blocks staging `*.tfvars`, `*.tfstate`, `.env`, and obvious AWS keys.
- If something sensitive is already tracked, run the helper:
  - Linux/macOS: `bash scripts/cleanup-secrets.sh`
  - Windows (PowerShell): `./scripts/cleanup-secrets.ps1`
  - Then remove from history if necessary (see below).

---

## 8) Deploy via GitHub Actions (optional)

1. In GitHub → Actions, run the Apply workflow.
2. It uses repository secrets for credentials and backend.

---

## 9) Connect to the Cluster Locally

1) Update kubeconfig:
- `aws eks --region eu-west-2 update-kubeconfig --name teaching-eks-cluster`

2) Verify:
- `kubectl get nodes`
- Expect nodes in Ready state.

---

## Optional: Deploy a Test App

- `kubectl create deployment hello-k8s --image=nginx --replicas=2`
- `kubectl expose deployment hello-k8s --port=80 --type=LoadBalancer`
- `kubectl get svc`
- Open the EXTERNAL-IP in the browser to see NGINX page.

---

## Done!

You’ve now:
- Set up Terraform backend (S3 + DynamoDB)
- Created IAM user + permissions
- Stored credentials in GitHub (optional)
- Installed AWS CLI & kubectl locally
- Deployed and connected to the Minimal EKS Cluster
- Verified the connection and deployed a test app

---

### Appendix: If secrets already exist in history
- Remove from current version: `git rm --cached path/to/secret.file && git commit -m "Stop tracking secrets"`
- Rewrite history (choose one):
  - BFG Repo-Cleaner: https://rtyley.github.io/bfg-repo-cleaner/
  - git filter-repo (recommended): https://github.com/newren/git-filter-repo
- Force-push after rewrite (coordinate with collaborators): `git push --force-with-lease`
