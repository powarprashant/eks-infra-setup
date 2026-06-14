variable "github_org" {
  description = "GitHub organisation or username that owns the repository (e.g. 'myorg' or 'myusername')"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. 'eks-infra-setup')"
  type        = string
  default     = "eks-infra-setup"
}

variable "aws_region" {
  description = "AWS region for the backend state bucket and DynamoDB table"
  type        = string
  default     = "ap-south-1"
}

variable "state_bucket" {
  description = "Name of the S3 bucket used for Terraform state (must already exist)"
  type        = string
  default     = "cloudcart-terraform-state"
}

variable "lock_table" {
  description = "Name of the DynamoDB table used for Terraform state locking"
  type        = string
  default     = "terraform-lock"
}

variable "role_name" {
  description = "Name of the IAM role GitHub Actions will assume"
  type        = string
  default     = "github-actions-terraform"
}

variable "create_oidc_provider" {
  description = "Set to false if an OIDC provider for token.actions.githubusercontent.com already exists in this account"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "terraform"
    Project     = "cloudcart"
    Purpose     = "github-actions-oidc"
  }
}
