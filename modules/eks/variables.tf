variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "cloudcart-eks"

  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "Cluster name cannot be empty."
  }
}

variable "public_subnet" {
  description = "Public subnet IDs (used for load balancers only)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet) >= 2
    error_message = "At least 2 public subnets required for high availability."
  }
}

variable "private_subnet" {
  description = "Private subnet IDs (used for worker nodes)"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet) >= 2
    error_message = "At least 2 private subnets required for high availability."
  }
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string

  validation {
    condition     = startswith(var.vpc_id, "vpc-")
    error_message = "VPC ID must start with 'vpc-'."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting EKS secrets at rest"
  type        = string

  validation {
    condition     = startswith(var.kms_key_arn, "arn:aws:kms:")
    error_message = "KMS key ARN must be a valid AWS KMS ARN."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "cloudcart"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
