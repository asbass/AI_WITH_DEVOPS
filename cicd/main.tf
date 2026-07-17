terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}
provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks_cluster.name]
  }
}
# Data source to get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-sg"
    }
  )
}

# No need to create additional subnet - using existing ones

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.kubernetes_version
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = false
    endpoint_public_access  = true
    public_access_cidrs    = var.public_access_cidrs
    security_group_ids     = [aws_security_group.eks_cluster_sg.id]
  }

  # Ensure proper order of resource creation and deletion
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = var.tags
}

# EKS Node Group (Managed)
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.desired_nodes
    max_size     = var.max_nodes
    min_size     = var.min_nodes
  }

  update_config {
    max_unavailable = 1
  }

  # Use Spot instances for cost savings
  capacity_type = var.use_spot_instances ? "SPOT" : "ON_DEMAND"

  # Instance configuration
  instance_types = [var.node_instance_type]
  
  disk_size = var.node_disk_size

  # Ensure proper order of resource creation and deletion
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = var.tags

  labels = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# OIDC Provider for IRSA (IAM Roles for Service Accounts)
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  tags = var.tags
}
# 1. Tạo một IAM Role chuyên dụng cho EBS CSI Driver (Đúng chuẩn IRSA)
resource "aws_iam_role" "ebs_csi_role" {
  name = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks_oidc.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

# 2. Gán quyền EBS CSI Driver vào Role mới này
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_role.name
}

# 3. Cài đặt Add-on EBS CSI Driver, trỏ vào Role mới
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.eks_cluster.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_driver_version
  service_account_role_arn = aws_iam_role.ebs_csi_role.arn
  
  depends_on = [aws_eks_node_group.eks_nodes]
}
# 1. Tạo IAM Role cho Jenkins
resource "aws_iam_role" "jenkins_role" {
  name = "${var.cluster_name}-jenkins-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks_oidc.arn }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub" = "system:serviceaccount:jenkins:jenkins-sa"
        }
      }
    }]
  })
}



# 2. Gán quyền ECR cho Role này
resource "aws_iam_role_policy_attachment" "jenkins_ecr_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role       = aws_iam_role.jenkins_role.name
}
resource "aws_iam_role" "build_role" {
  name = "DE00175-eks-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com" # Hoặc service nào Jenkins đang dùng
      }
    }]
  })
}


# 2. Tạo Policy cho phép DescribeCluster
resource "aws_iam_policy" "eks_describe_policy" {
  name        = "EKSDescribePolicy"
  description = "Cho phép Jenkins role describe cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = "*"
    }]
  })
}

# 3. Gắn Policy này vào Role
resource "aws_iam_role_policy_attachment" "attach_describe_policy" {
  role       = aws_iam_role.build_role.name
  policy_arn = aws_iam_policy.eks_describe_policy.arn
}
# 1. Tạo Access Entry cho jenkins_role (Role chuyên dụng của Jenkins)
#resource "aws_eks_access_entry" "jenkins_role_access" {
#  cluster_name      = aws_eks_cluster.eks_cluster.name
#  principal_arn     = aws_iam_role.jenkins_role.arn
#  type              = "STANDARD"
#}

# 2. Gán quyền Cluster Admin cho jenkins_role
#resource "aws_eks_access_policy_association" "jenkins_admin_access" {
 # cluster_name  = aws_eks_cluster.eks_cluster.name
#  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
#  principal_arn = aws_iam_role.jenkins_role.arn

 # access_scope {
  #  type = "cluster"
 # }
#}
# 1. Tạo Access Entry cho build role
# 1. Tạo Access Entry cho build role
resource "aws_eks_access_entry" "jenkins_build_role_access" {
  # THAY ĐỔI: Tham chiếu trực tiếp đến resource cluster thay vì viết cứng tên
  cluster_name  = aws_eks_cluster.eks_cluster.name 
  principal_arn = aws_iam_role.build_role.arn # Nên tham chiếu .arn thay vì viết cứng chuỗi
  type          = "STANDARD"
}

# 2. Gán quyền Admin (hoặc quyền đủ để Describe) cho role này
resource "aws_eks_access_policy_association" "jenkins_build_admin_access" {
  # THAY ĐỔI: Tham chiếu trực tiếp đến resource cluster
  cluster_name  = aws_eks_cluster.eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.build_role.arn # Nên tham chiếu .arn

  access_scope {
    type = "cluster"
  }
}
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  create_namespace = true
  depends_on = [aws_eks_node_group.eks_nodes]
}
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  namespace  = "kube-system"
}
