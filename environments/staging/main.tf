provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      Project     = "cloudcart"
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  cluster_name = "cloudcart-eks-staging"
}

##################################
# KMS
##################################

resource "aws_kms_key" "main" {
  description             = "EKS cluster KMS key — ${local.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

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

  vpc_name     = "cloudcart-vpc-staging"
  cluster_name = local.cluster_name
  environment  = "staging"

  tags = {
    Project     = "cloudcart"
    Environment = "staging"
  }
}

##################################
# EKS
##################################

module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = "1.31"
  environment     = "staging"

  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  kms_key_arn = aws_kms_key.main.arn

  node_instance_types = ["t2.micro"]
  node_desired_size   = 2
  node_max_size       = 2
  node_min_size       = 2
  node_disk_size      = 30

  tags = {
    Project     = "cloudcart"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}

##################################
# ECR
##################################

module "ecr" {
  source = "../../modules/ecr"
}
