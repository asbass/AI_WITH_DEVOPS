# 🚀 CI/CD Deployment Guide

This document describes how to deploy the complete DevOps platform on **AWS EKS** using **Terraform**, **Jenkins**, **Docker**, **Amazon ECR**, **NGINX Ingress**, **Prometheus**, and an **AI Self-Healing Agent**.

---

# Prerequisites

- AWS CLI
- kubectl
- Terraform
- Docker
- Helm
- Java 17+
- Python 3.10+

---

# 1. Configure Kubernetes

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name DE00175-eks
kubectl get nodes
```

---

# 2. Install NGINX Ingress

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/aws/deploy.yaml

kubectl -n ingress-nginx wait \
--for=condition=Available \
deployment/ingress-nginx-controller \
--timeout=180s
```

---

# 3. Create Storage & Namespace

```bash
kubectl apply -f sc.yaml

kubectl create namespace jenkins

kubectl apply -f pvc.yaml
```

---

# 4. Deploy Jenkins

```bash
kubectl apply -f jenkins-deploy.yaml
```

Get Jenkins URL

```bash
kubectl -n jenkins get svc jenkins-service \
-o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Get initial admin password

```bash
kubectl exec -it \
$(kubectl get pods -n jenkins -l app=jenkins -o name) \
-n jenkins \
-- cat /var/jenkins_home/secrets/initialAdminPassword
```

Port Forward (Optional)

```bash
kubectl port-forward svc/jenkins-service 8080:80 -n jenkins
```

---

# 5. Register Jenkins Agent

Create a **Permanent Agent** from Jenkins:

- Remote Root: `/home/ubuntu/jenkins`
- Label: `ec2-build`
- Launch Method: **Launch agent by connecting it to the controller**

Run on EC2:

```bash
mkdir -p ~/jenkins
cd ~/jenkins

JENKINS_URL=http://<JENKINS_URL>

curl -O ${JENKINS_URL}/jnlpJars/agent.jar

java -jar agent.jar \
-url "${JENKINS_URL}/" \
-secret <JENKINS_SECRET> \
-name worker \
-webSocket \
-workDir "/home/ubuntu/jenkins"
```

---

# 6. Login Amazon ECR

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

REGION=ap-southeast-1

REPO=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/de00175-app

aws ecr get-login-password --region $REGION \
| docker login --username AWS --password-stdin $REPO
```

Build & Push

```bash
docker build -t $REPO:latest .
docker push $REPO:latest
```

---

# 7. Generate Kubernetes Manifest

```bash
RDS_ENDPOINT=$(terraform output -raw mysql_endpoint)

sed \
-e "s|REPLACE_WITH_RDS_ENDPOINT|$RDS_ENDPOINT|g" \
-e "s|REPLACE_WITH_PASSWORD|<DB_PASSWORD>|g" \
-e "s|REPLACE_WITH_ECR_URI:latest|$REPO:latest|g" \
app.yaml > app_final.yaml
```

Deploy

```bash
kubectl apply -f app_final.yaml --namespace=app
```

---

# 8. Install Prometheus

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update

kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

---

# 9. Configure AI Agent

Install dependencies

```bash
pip install python-telegram-bot kubernetes openai requests
```

Environment variable

```bash
export OPENROUTER_API_KEY=<OPENROUTER_API_KEY>
```

RBAC

```bash
kubectl apply -f agent-rbac.yaml
```

---

# AI Self-Healing Flow

```text
Prometheus
      │
      ▼
Detect Incident
      │
      ▼
Collect Logs
      │
      ▼
AI Root Cause Analysis
      │
      ▼
Telegram Alert
      │
      ▼
Rollback Deployment
      │
      ▼
Verify Rollout
```

---

# Troubleshooting

Check pods

```bash
kubectl get pods -A
```

Check services

```bash
kubectl get svc -A
```

Check ingress

```bash
kubectl get ingress -A
```

Describe pod

```bash
kubectl describe pod <pod-name>
```

Logs

```bash
kubectl logs <pod-name>
```

Rollout status

```bash
kubectl rollout status deployment/<deployment-name>
```

---

# Notes

- Do not commit secrets or passwords.
- Replace placeholders before deployment.
- Store sensitive values in Kubernetes Secrets or AWS Secrets Manager.
