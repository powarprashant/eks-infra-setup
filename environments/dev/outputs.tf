output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ecr_frontend_url" {
  description = "ECR URL for the frontend image"
  value       = module.ecr.frontend_repo_url
}

output "ecr_backend_url" {
  description = "ECR URL for the backend image"
  value       = module.ecr.backend_repo_url
}
