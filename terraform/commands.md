# Commands: EKS Cluster (Terraform + kubectl)

Prerequisites
- CLI tools: `terraform` (>= 1.6), `aws`, `kubectl`, `helm`.
- AWS credentials configured (e.g., `aws configure` or environment variables).

Backend and Variables
- Backend file provided: `backend.tfvars`
  - `bucket=devops-class-eks-unique`
  - `key=eks/teaching-eks-cluster/terraform/terraform.tfstate`
  - `region=eu-west-2`
  - `dynamodb_table=eks-teaching-tflock`
- Variables file: `terraform.tfvars` (includes `admin_principal_arn` and defaults).

Initialize
- One-time or after backend changes:
  - `terraform init -backend-config=backend.tfvars -reconfigure`

Plan & Apply
- Plan: `terraform plan -var-file="terraform.tfvars"`
- Apply (interactive): `terraform apply -var-file="terraform.tfvars"`
- Apply (non-interactive): `terraform apply -var-file="terraform.tfvars" -auto-approve`

Connect To Cluster
- `aws eks --region eu-west-2 update-kubeconfig --name teaching-eks-cluster`
- Verify connectivity:
  - `kubectl get nodes -o wide`
  - `kubectl get pods -n kube-system`
  - `helm list -n kube-system | grep aws-load-balancer-controller`

Ingress Controller (ALB)
- Installed by Terraform via `helm_release.aws_load_balancer_controller`.
- VPC/subnets are tagged for public ALBs; check:
  - `aws ec2 describe-subnets --region eu-west-2 --filters Name=tag:kubernetes.io/role/elb,Values=1`

Useful Outputs
- `terraform output`

Destroy
- `terraform destroy -var-file="terraform.tfvars"`

Tips
- If you change backend values: `terraform init -backend-config=backend.tfvars -reconfigure`
- Check caller identity: `aws sts get-caller-identity`
- Inspect cluster: `kubectl get svc -A && kubectl get ingress -A`

Kubectl Contexts
- `kubectl config current-context`
- `kubectl config get-contexts`
- `kubectl config use-context <context-name>`

## Hello World Helm Chart

Step 1: Scaffold the chart
- Create a new chart: `helm create hello-world`
- Use a separate namespace: `kubectl create namespace demo || true`

Step 2: What files you get (and why)
- `hello-world/Chart.yaml`: Chart metadata (name, version, appVersion).
- `hello-world/values.yaml`: Default values referenced by templates (image, service, ingress).
- `hello-world/.helmignore`: Files to ignore when packaging.
- `hello-world/charts/`: Optional subcharts directory (empty by default).
- `hello-world/templates/` (Kubernetes manifests generated from values):
  - `deployment.yaml`: Pod spec and replica settings for the app.
  - `service.yaml`: Stable ClusterIP service for intra-cluster access.
  - `ingress.yaml`: Optional Ingress resource (disabled by default).
  - `serviceaccount.yaml`: Optional ServiceAccount if enabled.
  - `hpa.yaml`: Optional HorizontalPodAutoscaler if enabled.
  - `tests/test-connection.yaml`: Simple test pod created by `helm test`.

Step 3: Example values.yaml that works with ALB
Replace the content of `hello-world/values.yaml` with the below example (uses `nginxdemos/hello` and AWS Load Balancer Controller):

```yaml
replicaCount: 1

image:
  repository: nginxdemos/hello
  pullPolicy: IfNotPresent
  tag: "latest"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  automount: true
  annotations: {}
  name: ""

podAnnotations: {}
podLabels: {}

podSecurityContext: {}
securityContext: {}

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: "" # leave empty; use annotation below for AWS ALB Controller
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
  hosts:
    - host: "" # empty matches all hosts, access via the ALB DNS name
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources: {}

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 2
  targetCPUUtilizationPercentage: 80

nodeSelector: {}
affinity: {}
tolerations: []
```

Step 4: Install the chart
- Lint: `helm lint ./hello-world`
- Render (optional): `helm template hello-world ./hello-world -n demo | less`
- Install: `helm install hello-world ./hello-world -n demo --create-namespace`

Step 5: Verify and find the ALB
- Pods: `kubectl get pods -n demo -o wide`
- Ingress: `kubectl get ingress -n demo -w`
- Get ALB DNS: `kubectl get ingress hello-world -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'`
- Test: `curl http://<alb-dns-name>/`

How Helm releases work
- A release is an installed instance of a chart in a namespace with a unique name.
- List releases: `helm list -n demo`
- Inspect a release: `helm status hello-world -n demo`
- Show values used: `helm get values hello-world -n demo`

Upgrade and rollback
- Change `hello-world/values.yaml`, then:
  - `helm upgrade hello-world ./hello-world -n demo`
- View history: `helm history hello-world -n demo`
- Roll back to a previous revision (e.g., 1):
  - `helm rollback hello-world 1 -n demo`

Cleanup
- Uninstall the release: `helm uninstall hello-world -n demo`
- Optionally remove the namespace: `kubectl delete namespace demo`

Step 6: Make a change and rollback
- Make a visible change in `hello-world/values.yaml` (examples):
  - Change replicas: `replicaCount: 2` (from 1)
  - Or change image tag: `image.tag: "plain-text"` (any valid tag for `nginxdemos/hello`)
- Apply the change: `helm upgrade hello-world ./hello-world -n demo`
- Check history: `helm history hello-world -n demo`
- Roll back to a previous revision (e.g., 1): `helm rollback hello-world 1 -n demo --wait`
- Verify: `helm status hello-world -n demo`

About Helm Releases
- A release is a named, versioned deployment of a chart in a namespace.
- Each `install` creates revision 1; each `upgrade` increments the revision.
- `history`, `status`, and `get values|manifest` let you inspect past and current state.
- `rollback` re-applies the rendered manifests from a previous revision.

Common Helm Commands
- Repositories
  - Add repo: `helm repo add <name> <url>`
  - List repos: `helm repo list`
  - Update repo indexes: `helm repo update`
  - Search configured repos: `helm search repo <pattern>`
  - Search Artifact Hub: `helm search hub <pattern>`
- Install/Upgrade
  - Install: `helm install <release> <chart> -n <ns> --create-namespace -f values.yaml`
  - Upgrade: `helm upgrade <release> <chart> -n <ns> -f values.yaml`
  - Show default values of a chart: `helm show values <chart>`
  - Render templates locally: `helm template <release> <chart> -n <ns> -f values.yaml`
- Inspect/Debug
  - List releases: `helm list -n <ns>`
  - Status: `helm status <release> -n <ns>`
  - History: `helm history <release> -n <ns>`
  - Get values: `helm get values <release> -n <ns>`
  - Get manifest: `helm get manifest <release> -n <ns>`
  - Lint: `helm lint <chart-dir>`
- Rollback/Uninstall
  - Rollback: `helm rollback <release> <revision> -n <ns> --wait`
  - Uninstall: `helm uninstall <release> -n <ns>`

Common Helm Repositories
- Bitnami: `helm repo add bitnami https://charts.bitnami.com/bitnami`
- Prometheus Community: `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`
- Ingress NGINX: `helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx`
- Grafana: `helm repo add grafana https://grafana.github.io/helm-charts`
- Jetstack (cert-manager): `helm repo add jetstack https://charts.jetstack.io`
- AWS EKS charts: `helm repo add eks https://aws.github.io/eks-charts`
- Kubernetes SIGs ExternalDNS: `helm repo add kubernetes-sigs https://kubernetes-sigs.github.io/external-dns/`

Examples
- Search for nginx charts in your repos: `helm search repo nginx`
- Inspect default values for ingress-nginx: `helm show values ingress-nginx/ingress-nginx | less`
