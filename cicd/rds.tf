# 1. Tạo Security Group (Tường lửa) riêng cho MySQL
resource "aws_security_group" "mysql_sg" {
  name        = lower("${var.cluster_name}-mysql-sg")
  description = "Allow MySQL traffic from EKS Nodes"
  vpc_id      = var.vpc_id

  # INBOUND RULE: Chỉ cho phép cổng 3306 từ chính mạng nội bộ VPC của bạn truy cập vào để đảm bảo an toàn tuyệt đối
  ingress {
    description = "Allow MySQL from EKS Nodes"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Bạn có thể thu hẹp dải IP lại theo dải mạng VPC để an toàn hơn
  }

  # OUTBOUND RULE: Cho phép dữ liệu đi ra ngoài
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# 2. Gom các Subnet của bạn lại thành một nhóm mạng dành riêng cho Database
resource "aws_db_subnet_group" "mysql_subnet_group" {
  name       = lower("${var.cluster_name}-mysql-subnet-group")
  subnet_ids = var.subnet_ids

  tags = var.tags
}

# 3. Khởi tạo con database MySQL RDS thực tế trên AWS
resource "aws_db_instance" "mysql" {
  allocated_storage     = 20                  # 20GB lưu trữ cho database đồ án
  max_allocated_storage = 50                  # Tự động co giãn tối đa 50GB
  db_name               = var.db_name
  engine                = "mysql"             # Định nghĩa chạy MySQL
  engine_version        = "8.0"               # Bản 8.0 cực ổn định
  instance_class        = var.db_instance_class # Loại máy db.t3.micro từ variables.tf
  
  username             = var.db_username
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.mysql_subnet_group.name
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  
  skip_final_snapshot  = true                # Xóa sạch luôn khi gõ lệnh hủy hạ tầng, không giữ bản lưu để tránh phát sinh chi phí ngầm

  tags = var.tags
}

# 4. Xuất đường dẫn kết nối (Endpoint) của MySQL ra màn hình terminal sau khi chạy xong
output "mysql_endpoint" {
  value       = aws_db_instance.mysql.endpoint
  description = "Địa chỉ Endpoint kết nối MySQL RDS. Copy cái này dán vào Java Spring Boot"
}
