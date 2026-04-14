variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs — used by the EKS control plane and load balancers"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs — worker nodes are placed here"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN for Kubernetes secrets encryption and CloudWatch log group encryption. Leave empty to skip encryption (non-prod only — required for financial/compliance workloads)."
  type        = string
  default     = ""
}

variable "public_access_cidrs" {
  description = "CIDRs permitted to reach the Kubernetes API public endpoint. Restrict to your VPN/office CIDR in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_public_endpoint" {
  description = "Whether to expose the Kubernetes API server publicly. Set false for fully-private clusters."
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes. Use t3.large minimum for production financial workloads."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes (for cluster autoscaler upper bound)"
  type        = number
  default     = 4
}

variable "node_min_size" {
  description = "Minimum number of worker nodes — keep >= 2 for HA"
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "Root EBS disk size in GB for each worker node"
  type        = number
  default     = 20
}

variable "environment" {
  description = "Environment name — applied as a node label for workload scheduling"
  type        = string
  default     = "dev"
}

variable "jenkins_role_arn" {
  description = "IAM role ARN for the Jenkins EC2 instance profile. Added as cluster-admin via EKS Access Entry so the pipeline can run kubectl."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
