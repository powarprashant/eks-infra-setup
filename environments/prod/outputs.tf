output "cluster_name" {
  description = "EKS cluster name — use with: aws eks update-kubeconfig --name <value>"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — use this when creating IRSA roles for application workloads"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs — for any additional node groups or RDS subnets"
  value       = module.vpc.private_subnet_ids
}

output "ecr_frontend_url" {
  description = "ECR repository URL for frontend image — use in your CI/CD docker push command"
  value       = module.ecr.frontend_repo_url
}

output "ecr_backend_url" {
  description = "ECR repository URL for backend image — use in your CI/CD docker push command"
  value       = module.ecr.backend_repo_url
}

output "kms_key_arn" {
  description = "KMS key ARN — use for any additional resources requiring encryption"
  value       = aws_kms_key.main.arn
}
