
# 🚀 Student Setup Guide — Minimal EKS  Cluster

This guide will help you set up everything needed to connect to the **Minimal EKS Cluster**.

---

## 1️⃣ Create S3 Bucket for Terraform State

1. Log in to [AWS Console](https://aws.amazon.com/console/).
2. Go to **S3** → **Create bucket**.
3. Fill in:
   - **Bucket name**: `eks-teaching-tfstate-YOURNAME`
   - **Region**: `eu-west-2` (or as provided by instructor)
4. **Uncheck** "Block all public access".
5. Leave other settings default → **Create bucket**.

---

## 2️⃣ Create DynamoDB Table for State Locking

1. Go to **DynamoDB** → **Create table**.
2. Table name: `eks-teaching-tflock`
3. Partition key: `LockID` (String)
4. Leave other settings default → **Create table**.

---

## 3️⃣ Create IAM User for Terraform

1. Go to **IAM** → **Users** → **Add users**.
2. Username: `eks-terraform-user`
3. Select **Access key - Programmatic access**.
4. Click **Next: Permissions** → **Attach policies directly**:
   - `AmazonEKSClusterPolicy`
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEC2FullAccess`
   - `AmazonS3FullAccess`
   - `AmazonDynamoDBFullAccess`
   - `IAMFullAccess`
5. Complete creation and **download the Access Key ID and Secret Access Key**.

---

## 4️⃣ Store AWS Credentials in GitHub Secrets

1. Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions**.
2. Add the following secrets:
   - `AWS_ACCESS_KEY_ID` → from IAM user
   - `AWS_SECRET_ACCESS_KEY` → from IAM user
   - `AWS_REGION` → `eu-west-2` (or your region)
   - `TF_BACKEND_BUCKET` → S3 bucket name
   - `TF_BACKEND_TABLE` → DynamoDB table name
   - `TF_BACKEND_KEY` → `eks/terraform.tfstate`

---

## 5️⃣ Install AWS CLI

### **Windows**
1. Download: [AWS CLI v2 MSI](https://awscli.amazonaws.com/AWSCLIV2.msi)
2. Install → verify:
   ```powershell
   aws --version
````

### **macOS**

```bash
brew install awscli
aws --version
```

### **Linux**

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

---

## 6️⃣ Install kubectl

### **Windows**

```powershell
choco install kubernetes-cli
kubectl version --client
```

### **macOS**

```bash
brew install kubectl
kubectl version --client
```

### **Linux**

```bash
curl -o kubectl https://amazon-eks.s3.amazonaws.com/1.29.0/2023-11-14/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
```

---

## 7️⃣ Authenticate AWS CLI Locally

If you created the IAM user earlier:

```bash
aws configure
```

Enter:

* AWS Access Key ID → from IAM user
* AWS Secret Access Key → from IAM user
* Default region → `eu-west-2`
* Output format → `json` (or leave blank)

---

## 8️⃣ Deploy EKS Cluster via GitHub Actions

1. Go to your GitHub repo → **Actions** tab.
2. Select **Apply EKS** workflow → **Run workflow** → Confirm.
3. Wait for the workflow to complete.

---

## 9️⃣ Connect to the Cluster Locally

After Apply workflow finishes:

```bash
aws eks update-kubeconfig \
  --region eu-west-2 \
  --name teaching-eks-cluster
```

Verify:

```bash
kubectl get nodes
```

You should see **2 nodes** in `Ready` state.

---

## 🔟 (Optional) Deploy a Test App

```bash
kubectl create deployment hello-k8s --image=nginx --replicas=2
kubectl expose deployment hello-k8s --port=80 --type=LoadBalancer
kubectl get svc
```

Open the **EXTERNAL-IP** in your browser — you’ll see the NGINX welcome page.

---

## 🎯 Done!

You’ve now:

* Set up Terraform backend (S3 + DynamoDB)
* Created IAM user + permissions
* Stored credentials in GitHub
* Installed AWS CLI & kubectl locally
* Connected to the Minimal EKS Cluster
* Verified the connection and deployed a test app

```


