##############################################################
# PRODUCTION ENVIRONMENT — Financial Domain
#
# Architecture:
#   VPC  → 3 AZs, NAT per AZ, VPC Flow Logs (KMS encrypted)
#   EKS  → 1.31, private nodes, all addons, API auth mode
#   ECR  → immutable tags, scan-on-push, lifecycle policies
#   KMS  → one key per cluster with root + CloudWatch Logs policy
##############################################################

provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  cluster_name = "cloudcart-eks-prod"
  environment  = "prod"

  common_tags = {
    Project     = "cloudcart"
    Environment = local.environment
    ManagedBy   = "terraform"
    Domain      = "financial"
    CostCenter  = "prod-infra"
  }
}

##################################
# KMS Key
#
# One key per cluster with a policy granting:
#   - Root account full control (prevents lock-out)
#   - CloudWatch Logs service encrypt/decrypt
#     (required for VPC Flow Logs + EKS control plane logs)
#
# Used for: EKS secrets, VPC Flow Logs, EKS CW log group
##################################

resource "aws_kms_key" "main" {
  description             = "EKS cluster KMS key — ${local.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsEncryption"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = { Name = "${local.cluster_name}-key" }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.cluster_name}"
  target_key_id = aws_kms_key.main.key_id
}

##################################
# VPC
##################################

module "vpc" {
  source = "../../modules/vpc"

  vpc_name    = "cloudcart-vpc-prod"
  vpc_cidr    = "10.0.0.0/16"
  cluster_name = local.cluster_name
  environment = local.environment

  # 3 AZs — one NAT Gateway per AZ for high availability
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]

  # VPC Flow Logs required for financial compliance
  enable_flow_logs = true
  kms_key_arn      = aws_kms_key.main.arn

  tags = local.common_tags
}

##################################
# EKS
##################################

module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = "1.31"
  environment     = local.environment

  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  kms_key_arn = aws_kms_key.main.arn

  # TODO: restrict to your VPN/office CIDR before go-live
  # e.g. public_access_cidrs = ["203.0.113.0/24"]
  public_access_cidrs    = ["0.0.0.0/0"]
  enable_public_endpoint = true

  # Production node sizing — t3.large minimum for financial workloads
  node_instance_types = ["t3.large"]
  node_desired_size   = 3
  node_max_size       = 6
  node_min_size       = 2
  node_disk_size      = 50

  tags = local.common_tags
}

##################################
# ECR
##################################

module "ecr" {
  source = "../../modules/ecr"
}
