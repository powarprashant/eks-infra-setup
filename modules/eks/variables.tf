variable "cluster_name" {
  type    = string
  default = "cloudcart-eks"
}

variable "public_subnet" {
  type = list(string)
}

variable "private_subnet" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "tags" {
  type = map(string)

  default = {
    Project     = "cloudcart"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}