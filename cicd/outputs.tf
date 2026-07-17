output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.eks_cluster.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.eks_cluster.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.eks_cluster_sg.id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.eks_cluster.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster's OIDC Issuer"
  value       = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.eks_nodes.id
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.eks_nodes.status
}

output "configure_kubectl" {
  description = "Command to configure kubectl to connect to the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.eks_cluster.name}"
}

output "cluster_addons_command" {
  description = "Commands to install essential cluster addons"
  value = {
    metrics_server = "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
    aws_ebs_csi    = "eksctl create addon --cluster ${aws_eks_cluster.eks_cluster.name} --name aws-ebs-csi-driver --region ${var.aws_region}"
  }
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost for this EKS setup"
  value = {
    eks_control_plane = "$73.00 (0.10 USD/hour)"
    worker_nodes      = var.use_spot_instances ? "~$11.00 (t3.medium spot)" : "~$30.40 (t3.medium on-demand)"
    total_estimated   = var.use_spot_instances ? "~$84.00/month" : "~$103.40/month"
  }
}

output "cost_saving_tips" {
  description = "Tips to reduce costs further"
  value = {
    tip_1 = "Using Spot instances (already enabled) saves ~70% on compute"
    tip_2 = "Scale down to 0 nodes when not in use: kubectl scale deployment --all --replicas=0 -n default"
    tip_3 = "Destroy cluster when not needed: terraform destroy"
    tip_4 = "Use kubectl top nodes/pods to monitor resource usage"
  }
}

output "important_notes" {
  description = "Important information about this cluster"
  value = {
    note_1 = "This is a MINIMAL setup for learning - not for production"
    note_2 = "Only 1 worker node (t3.medium) with 4GB RAM by default"
    note_3 = "Spot instances can be interrupted - data may be lost"
    note_4 = "Remember to destroy resources to avoid charges: terraform destroy"
  }
}