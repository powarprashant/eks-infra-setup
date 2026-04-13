output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint URL"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate — used to verify the API server TLS cert"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — pass this when creating IRSA roles for workloads"
  value       = aws_iam_openid_connect_provider.main.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL without https:// — used in IRSA trust policy StringEquals conditions"
  value       = replace(aws_iam_openid_connect_provider.main.url, "https://", "")
}

output "node_role_arn" {
  description = "IAM role ARN for worker nodes — attach additional policies here for workloads that need AWS access"
  value       = aws_iam_role.node.arn
}
