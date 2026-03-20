terraform {

  backend "s3" {

    bucket = "cloudcart-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "ap-south-1"

    dynamodb_table = "terraform-lock"
  }

}