provider "aws" {
  region = "ap-south-1"
}

############################
# KMS Key for EKS Encryption
############################

resource "aws_kms_key" "eks" {
  description             = "KMS key for encrypting Kubernetes secrets in EKS"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "eks" {
  name          = "alias/eks-secrets"
  target_key_id = aws_kms_key.eks.key_id
}

############################
# VPC Module
############################

module "vpc" {
  source = "../../modules/vpc"
}

############################
# EKS Module
############################

module "eks" {
  source = "../../modules/eks"

  public_subnet  = module.vpc.public_subnet
  private_subnet = module.vpc.private_subnet
  vpc_id         = module.vpc.vpc_id

  kms_key_arn = aws_kms_key.eks.arn
}

############################
# RDS Module
############################

module "rds" {
  source = "../../modules/rds"

  db_username = "admin"
  db_password = var.db_password
}

############################
# ECR Module
############################

module "ecr" {
  source = "../../modules/ecr"
}