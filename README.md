# 🤖 AI Kubernetes Self-Healing Agent

An AI-powered Kubernetes remediation agent that continuously monitors cluster health, performs root cause analysis (RCA), sends Telegram alerts, and automatically recovers failed workloads using Llama 3.1 via OpenRouter.

---

## Overview

This project demonstrates how Large Language Models (LLMs) can assist Site Reliability Engineering (SRE) by automating incident detection and recovery inside a Kubernetes cluster.

The agent continuously monitors Kubernetes resources and Prometheus metrics. When an incident is detected, it:

1. Detects the failure.
2. Collects Kubernetes logs and events.
3. Performs AI-powered Root Cause Analysis (RCA).
4. Sends a detailed Telegram notification.
5. Executes automatic rollback when appropriate.
6. Verifies the rollout status before reporting success.

---

## Features

- AI-powered Root Cause Analysis
- Kubernetes Health Monitoring
- Telegram ChatOps
- Prometheus Metrics Integration
- Automatic Rollback
- Rollout Verification
- CrashLoopBackOff Detection
- ImagePullBackOff Detection
- HTTP 5xx Monitoring
- Kubernetes Event Collection

---

## Architecture

```text
              Prometheus
                   │
                   ▼
          Monitoring Watchdog
                   │
                   ▼
         Kubernetes API Server
                   │
                   ▼
        AI Self-Healing Agent
         │              │
         │              ▼
         │       OpenRouter
         │        Llama 3.1
         │
         ▼
Telegram Notification
         │
         ▼
Rollback Deployment
         │
         ▼
Verify Rollout
```

---

## Project Structure

```text
.
├── agent.py
├── requirements.txt
├── Dockerfile
├── deployment.yaml
├── agent-rbac.yaml
└── README.md
```

---

## Technologies

- Python
- Kubernetes API
- Prometheus
- Telegram Bot API
- OpenRouter API
- Llama 3.1
- Docker

---

## Workflow

```text
Watchdog
    │
    ▼
Detect Incident
    │
    ▼
Collect Logs
    │
    ▼
Analyze Root Cause
    │
    ▼
Send Telegram Alert
    │
    ▼
Rollback Deployment
    │
    ▼
Verify Recovery
```

---

## Deployment

Install dependencies

```bash
pip install -r requirements.txt
```

Deploy RBAC

```bash
kubectl apply -f agent-rbac.yaml
```

Deploy Agent

```bash
kubectl apply -f deployment.yaml
```

---

## Environment Variables

```text
OPENROUTER_API_KEY=<YOUR_API_KEY>

TELEGRAM_BOT_TOKEN=<YOUR_TOKEN>

TELEGRAM_CHAT_ID=<YOUR_CHAT_ID>

PROMETHEUS_URL=http://prometheus.monitoring.svc.cluster.local:9090
```

---

## Demo Scenario

Example incident:

- Deploy an invalid Docker image.
- Kubernetes reports `ImagePullBackOff`.
- The agent detects the failure.
- Logs and events are collected.
- AI generates a Root Cause Analysis.
- A Telegram alert is sent.
- The deployment is rolled back automatically.
- The rollout status is verified.

---

## Related Project

This AI Agent integrates with the Cloud Native CI/CD platform below:

➡️ https://github.com/asbass/cicd
---

## Future Improvements

- Multi-cluster support
- Slack and Microsoft Teams notifications
- Argo Rollouts integration
- Grafana dashboard
- AI incident summarization
- Multi-agent architecture

---

## License

MIT License
