resource "aws_ecr_repository" "app" {
  name                 = "de00175-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # cho phép terraform destroy ngay cả khi còn image

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}
