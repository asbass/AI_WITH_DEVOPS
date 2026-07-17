# EC2 build machine — làm Jenkins JNLP agent
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "tls_private_key" "build" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "build" {
  key_name   = "${var.cluster_name}-build"
  public_key = tls_private_key.build.public_key_openssh
  tags       = var.tags
}

resource "local_file" "build_private_key" {
  content         = tls_private_key.build.private_key_pem
  filename        = "${path.module}/build-machine-key.pem"
  file_permission = "0600"
}
resource "aws_iam_role_policy_attachment" "build_ecr" {
  role       = aws_iam_role.build_role.name  # ĐÃ SỬA: Trỏ sang main.tf
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_instance_profile" "build" {
  name = "${var.cluster_name}-build-profile"
  role = aws_iam_role.build_role.name  # ĐÃ SỬA: Trỏ sang main.tf
}
resource "aws_security_group" "build" {
  name        = "${var.cluster_name}-build-sg"
  description = "Jenkins build machine"
  vpc_id      = var.vpc_id  # ĐÃ SỬA: dùng biến var.vpc_id trực tiếp

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "de00175-ec2" })
}

resource "aws_instance" "build" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  subnet_id     = var.subnet_ids[0] # ĐÃ SỬA: dùng biến var.subnet_ids trực tiếp
  vpc_security_group_ids = [aws_security_group.build.id]
  key_name      = aws_key_pair.build.key_name
  iam_instance_profile   = aws_iam_instance_profile.build.name

  associate_public_ip_address = true

  user_data = <<-EOT
    #!/bin/bash
    set -e
    apt-get update
    apt-get install -y openjdk-21-jre-headless docker.io unzip git curl
    curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscli.zip
    unzip -q /tmp/awscli.zip -d /tmp
    /tmp/aws/install
    curl -fsSL https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
    chmod +x /usr/local/bin/kubectl
    usermod -aG docker ubuntu
    systemctl enable --now docker
  EOT

  tags = merge(var.tags, { Name = "de00175-ec2" })
}

output "build_machine_public_ip" {
  value = aws_instance.build.public_ip
}
