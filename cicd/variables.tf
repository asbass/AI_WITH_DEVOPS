variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "DE00175-eks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.35" # ĐÃ SỬA: Hạ từ 1.35 xuống 1.31 để các addon (EBS, ALB) chạy ổn định, không lỗi
}

# Network Configuration - Using existing VPC/Subnet from the other setup
variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
  default     = "vpc-036b914bdf14d227e"
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster (requires at least 2 in different AZs)"
  type        = list(string)
  default     = ["subnet-0a5be78d1fa101e87", "subnet-00cd9499101129734"] # ap-southeast-1a and 1b
}

# ==========================================
# ĐÃ SỬA: Cấu hình lại Node Group để đủ RAM gánh Jenkins/ArgoCD
# ==========================================
variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.large" # ĐÃ SỬA: Đổi sang m6i.large (2 vCPU, 8GB RAM) giống mock project để bao mượt
}

variable "desired_nodes" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2 # ĐÃ SỬA: Tăng từ 1 lên 2 máy để chạy High Availability và đủ tài nguyên gánh app
}

variable "min_nodes" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2 # ĐÃ SỬA: Tối thiểu là 2
}

variable "max_nodes" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3 # Cho phép co giãn lên tối đa 3 máy khi Jenkins build nặng
}

variable "node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 30 # ĐÃ SỬA: Tăng từ 20GB lên 30GB vì Jenkins lưu trữ source code và docker image khá nặng
}

variable "use_spot_instances" {
  description = "Use Spot instances for cost savings (can be interrupted)"
  type        = bool
  default     = true # Giữ nguyên true để tiết kiệm tiền tài khoản AWS nhé
}

# Access Configuration
variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the EKS API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "devops-class"
    ManagedBy   = "terraform"
    Purpose     = "learning"
  }
}

# EBS CSI Driver Configuration
variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver addon"
  type        = string
  default     = "v1.60.0-eksbuild.1"
}

# ==========================================
# THÊM MỚI: Các biến để cấu hình MySQL RDS
# ==========================================
variable "db_instance_class" {
  description = "Loại máy ảo cho Database"
  type        = string
  default     = "db.t3.micro" # Siêu rẻ, nằm trong gói Free Tier nếu tài khoản mới
}

variable "db_name" {
  description = "Tên database khởi tạo"
  type        = string
  default     = "gameboard"
}

variable "db_username" {
  description = "Tài khoản admin của database"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Tai123456789(Nên đổi lại bảo mật hơn)"
  type        = string
  sensitive   = true # Thuộc tính ẩn mật khẩu khi Terraform in log ra màn hình
  default     = "Tai123456789"
}
	
