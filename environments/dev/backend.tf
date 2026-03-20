terraform {

  required_version = ">= 1.5"

  backend "s3" {
    bucket         = "cloudcart-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-lock"
  }

}