output "role_arn" {
  description = "ARN of the IAM role — set this as the AWS_GITHUB_ACTIONS_ROLE_ARN secret in your GitHub repository"
  value       = aws_iam_role.github_actions.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.github_actions.name
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = local.oidc_provider_arn
}
