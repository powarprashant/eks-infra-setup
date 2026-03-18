resource "aws_ecr_repository" "frontend_repo" {
  name = "cloudcart-frontend"
}

resource "aws_ecr_repository" "backend_repo" {
  name = "cloudcart-backend"
}