# AI_WITH_DEVOPS
# 🤖 AI_WITH_DEVOPS

An AI-powered Self-Healing DevOps platform built on AWS EKS.

This project demonstrates a complete DevOps workflow that combines Kubernetes, Jenkins, Terraform, Prometheus, Amazon ECR and an AI Agent (Llama 3.1 via OpenRouter) to automatically detect incidents, notify administrators through Telegram and perform intelligent remediation.

---

## 🚀 Features

- CI/CD Pipeline with Jenkins
- Infrastructure as Code using Terraform
- Kubernetes Deployment on AWS EKS
- Docker Image Registry (Amazon ECR)
- NGINX Ingress Controller
- Prometheus Monitoring
- Telegram Alerting
- AI-powered Root Cause Analysis
- Automatic Rollback (Self-Healing)

---

## 🏗 Architecture

```text
                GitHub
                   │
                   ▼
             Jenkins Pipeline
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
 Docker Build           Terraform Apply
        │                     │
        ▼                     ▼
   Amazon ECR            AWS Infrastructure
        │
        ▼
 Kubernetes (Amazon EKS)
        │
        ▼
  NGINX Ingress Controller
        │
        ▼
   Application Service
        │
        ▼
    Prometheus Metrics
        │
        ▼
   AI Monitoring Agent
        │
        ▼
 Telegram Notification
        │
        ▼
 Automatic Rollback
```

---

# 📦 Tech Stack

| Category | Technology |
|----------|------------|
| Cloud | AWS |
| Container | Docker |
| Orchestration | Kubernetes (EKS) |
| CI/CD | Jenkins |
| IaC | Terraform |
| Registry | Amazon ECR |
| Monitoring | Prometheus |
| AI | Llama 3.1 (OpenRouter) |
| Programming | Python |
| Notification | Telegram Bot |

---

# 📁 Project Structure

```text
AI_WITH_DEVOPS
│
├── cicd/
│   ├── Jenkinsfile
│   ├── terraform/
│   ├── app.yaml
│   ├── sc.yaml
│   ├── pvc.yaml
│   ├── jenkins-deploy.yaml
│   ├── agent-rbac.yaml
│   └── README.md
│
├── NNFS_PygameMySQL/
│
└── README.md
```

---

# 🔄 CI/CD Workflow

1. Developer pushes code to GitHub.
2. Jenkins detects repository changes.
3. Docker image is built automatically.
4. Image is pushed to Amazon ECR.
5. Kubernetes Deployment is updated.
6. Prometheus monitors application health.
7. AI Agent analyzes incidents.
8. Telegram sends notifications.
9. AI performs automatic rollback if necessary.

---

# 🧠 AI Self-Healing Workflow

```text
Prometheus
      │
      ▼
Watchdog Thread
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
Verify Rollout Status
      │
      ▼
Recovered
```

---

# 📊 Monitoring

The monitoring layer includes:

- HTTP 5xx error detection
- CrashLoopBackOff detection
- ImagePullBackOff detection
- Pod status monitoring
- Memory monitoring
- Kubernetes Event inspection
- Root Cause Analysis

---

# 🤖 AI Agent

The AI Agent uses OpenRouter with Llama 3.1 to:

- Understand administrator commands
- Analyze cluster health
- Collect Kubernetes logs
- Perform Root Cause Analysis
- Execute rollback
- Verify rollout status
- Prevent false-positive recovery

---

# 📖 Deployment Guide

Detailed deployment instructions are available in:

```text
cicd/README.md
```

---

# 📸 Screenshots

Recommended screenshots:

- Jenkins Dashboard
- Kubernetes Pods
- Telegram Alert
- Prometheus Dashboard
- AI Rollback
- Jenkins Pipeline

---

# 🔐 Security

Do **not** commit:

- API Keys
- Telegram Tokens
- Jenkins Secrets
- EC2 Public IP
- AWS Credentials
- Database Passwords

Use Kubernetes Secrets or AWS Secrets Manager instead.

---

# 📄 License

MIT License
