# Minimal EKS for Teaching — Two Node Groups (SPOT + ON_DEMAND)

This variant starts **two node groups** by default:
- **SPOT** group (labeled `pool=spot`), default size = 1
- **ON_DEMAND** group (labeled `pool=on-demand`), default size = 1

Total = **2 nodes**, perfect for teaching **node management**, **labels**, **cordon/drain**, and **pool-aware scheduling**.

## One-time: Backend (S3 + DynamoDB)
```bash
export AWS_REGION=eu-west-2
export TF_BACKEND_BUCKET=passy-eks-tfstate-demo
export TF_BACKEND_TABLE=passy-eks-tflock
export TF_BACKEND_KEY=eks/minimal/terraform.tfstate

aws s3api create-bucket --bucket "$TF_BACKEND_BUCKET" --region "$AWS_REGION"   --create-bucket-configuration LocationConstraint="$AWS_REGION"
aws s3api put-bucket-versioning --bucket "$TF_BACKEND_BUCKET"   --versioning-configuration Status=Enabled
aws dynamodb create-table   --table-name "$TF_BACKEND_TABLE"   --attribute-definitions AttributeName=LockID,AttributeType=S   --key-schema AttributeName=LockID,KeyType=HASH   --billing-mode PAY_PER_REQUEST
```

## One-time: Bootstrap GitHub OIDC role
```bash
cd bootstrap-iam
terraform init   -backend-config="bucket=$TF_BACKEND_BUCKET"   -backend-config="key=bootstrap/iam.tfstate"   -backend-config="region=$AWS_REGION"   -backend-config="dynamodb_table=$TF_BACKEND_TABLE"

terraform apply -auto-approve   -var "region=$AWS_REGION"   -var "github_org=YOUR_GH_ORG"   -var "repo_name=YOUR_REPO_NAME"   -var "branch=main"
```
Copy the printed `role_arn` and add repo secrets:
- `AWS_ROLE_TO_ASSUME`
- `AWS_REGION`
- `TF_BACKEND_BUCKET`, `TF_BACKEND_TABLE`, `TF_BACKEND_KEY`

## Apply from GitHub Actions
- **Actions → Apply EKS → Run workflow**
- Optional override sizes/types per run:
  ```
  spot_desired_size=1 spot_min_size=1 spot_max_size=2 od_desired_size=1 od_min_size=1 od_max_size=2   spot_instance_types='["t3.small"]' od_instance_types='["t3.small"]'
  ```

## Destroy from GitHub Actions
- **Actions → Destroy EKS → Run workflow**

## After apply (local kubeconfig)
```bash
aws eks --region $AWS_REGION update-kubeconfig --name teaching-eks-cluster
kubectl get nodes --show-labels
```

## Teaching demos
- **Show node groups**:
  ```bash
  aws eks list-nodegroups --cluster-name teaching-eks-cluster
  ```
- **Schedule to on-demand only**:
  ```yaml
  nodeSelector:
    pool: on-demand
  ```
- **Cordon/drain**:
  ```bash
  kubectl cordon <nodeName>
  kubectl drain <nodeName> --ignore-daemonsets --delete-emptydir-data
  kubectl uncordon <nodeName>
  ```

## Notes
- VPC is public-only; no NAT (cheaper). Prefer `kubectl port-forward` for demos.
- API server SG open to 0.0.0.0/0 for classroom speed; tighten in prod.
- Default EKS version is 1.29 (editable in `variables.tf`).
