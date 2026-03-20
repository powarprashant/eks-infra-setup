provider "aws" {
  region = "ap-south-1"
}

module "vpc" {
  source = "../../modules/vpc"
}

module "eks" {

  source = "../../modules/eks"

  public_subnet  = module.vpc.public_subnet
  private_subnet = module.vpc.private_subnet
}

module "rds" {

  source = "../../modules/rds"

  db_username = "admin"
  db_password = "securepassword"
}

module "ecr" {
  source = "../../modules/ecr"
}
