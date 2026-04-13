output "frontend_repo_url" {
  description = "ECR repository URL for the frontend image"
  value       = aws_ecr_repository.frontend_repo.repository_url
}

output "backend_repo_url" {
  description = "ECR repository URL for the backend image"
  value       = aws_ecr_repository.backend_repo.repository_url
}
