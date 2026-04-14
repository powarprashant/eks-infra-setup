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

  # Jenkins EC2 instance profile role — already attached to the Jenkins EC2.
  # Verified via: aws sts get-caller-identity → assumed-role/jenkins-eks-roles
  jenkins_role_arn = "arn:aws:iam::361357546722:role/jenkins-eks-roles"

  # kms_key_arn omitted — defaults to "" — no KMS encryption in dev (cost saving)
  # For prod, create a KMS key with logs.amazonaws.com in its key policy and pass the ARN here.

  # Dev sizing — t3.medium minimum for Bottlerocket + EKS system pods.
  # t2.micro (1GB RAM) causes node memory pressure before any app pods run:
  # Bottlerocket OS + vpc-cni + kube-proxy + coredns×2 + ebs-csi = ~950MB.
  # t3.medium (4GB RAM) leaves ~3GB free for workloads.
  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_max_size       = 2
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
