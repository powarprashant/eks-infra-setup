provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      Project     = "cloudcart"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  cluster_name = "cloudcart-eks-dev"
}

##################################
# VPC
# Flow logs disabled in dev — cost saving
##################################

module "vpc" {
  source = "../../modules/vpc"

  vpc_name     = "cloudcart-vpc-dev"
  cluster_name = local.cluster_name
  environment  = "dev"

  tags = {
    Project     = "cloudcart"
    Environment = "dev"
  }
}

##################################
# EKS
##################################

module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = "1.31"
  environment     = "dev"

  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  # kms_key_arn omitted — defaults to "" — no KMS encryption in dev (cost saving)
  # For prod, create a KMS key with logs.amazonaws.com in its key policy and pass the ARN here.

  # Dev sizing — minimal cost
  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_max_size       = 3
  node_min_size       = 1
  node_disk_size      = 20

  tags = {
    Project     = "cloudcart"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

##################################
# ECR
##################################

module "ecr" {
  source = "../../modules/ecr"
}
