#!/bin/bash
# Script cài đặt nhanh các công cụ
kubectl create namespace jenkins
kubectl create namespace argocd

# Cài đặt ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd

# Cài đặt Jenkins
helm repo add jenkinsci https://charts.jenkins.io
helm install jenkins jenkinsci/jenkins -n jenkins

echo "Hệ thống đã sẵn sàng!"
