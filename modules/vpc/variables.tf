variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — one per AZ. 3 recommended for production HA."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnets are required for high availability."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets — one per AZ. Must match count of public_subnet_cidrs."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnets are required for high availability."
  }
}

variable "cluster_name" {
  description = "EKS cluster name — required for Kubernetes subnet discovery tags (ALB/NLB controller)"
  type        = string
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch. Required for financial compliance and audit trail."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for VPC Flow Log CloudWatch log group encryption. Required when enable_flow_logs = true."
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
