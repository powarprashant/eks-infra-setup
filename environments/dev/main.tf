provider "aws" {
region = "ap-south-1"
}

####################################

# KMS Key for EKS Encryption

####################################

resource "aws_kms_key" "eks" {
description             = "EKS Kubernetes secrets encryption key"
deletion_window_in_days = 7
enable_key_rotation     = true
}

resource "aws_kms_alias" "eks" {
name          = "alias/eks-secrets"
target_key_id = aws_kms_key.eks.key_id
}

####################################

# VPC

####################################

module "vpc" {
source = "../../modules/vpc"
}

####################################

# EKS

####################################

module "eks" {
source = "../../modules/eks"

vpc_id = module.vpc.vpc_id

# ✅ FIXED: pass combined subnets (no unsupported args)

subnet_ids = concat(module.vpc.public_subnet, module.vpc.private_subnet)

# ✅ pass public subnet separately for node group

public_subnet = module.vpc.public_subnet

kms_key_arn = aws_kms_key.eks.arn
}

####################################

# RDS

####################################

module "rds" {
source = "../../modules/rds"

db_username = var.db_username
db_password = var.db_password
}

####################################

# ECR

####################################

module "ecr" {
source = "../../modules/ecr"
}
