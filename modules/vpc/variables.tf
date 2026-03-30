variable "vpc_name" {
description = "Name of the VPC"
type        = string
default     = "cloudcart-vpc"
}

variable "vpc_cidr" {
description = "CIDR block for VPC"
type        = string
default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
description = "CIDR blocks for public subnets"
type        = list(string)

default = [
"10.0.1.0/24",
"10.0.2.0/24"
]
}

variable "private_subnet_cidrs" {
description = "CIDR blocks for private subnets"
type        = list(string)

default = [
"10.0.11.0/24",
"10.0.12.0/24"
]
}

variable "availability_zones" {
description = "Availability zones for subnets"
type        = list(string)

default = [
"ap-south-1a",
"ap-south-1b"
]
}

variable "environment" {
description = "Environment name"
type        = string
default     = "dev"
}

variable "tags" {
description = "Common tags for all resources"
type        = map(string)

default = {
Project     = "cloudcart"
Environment = "dev"
Terraform   = "true"
}
}
