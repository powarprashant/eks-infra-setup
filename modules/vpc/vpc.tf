resource "aws_vpc" "cloudcart_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "cloudcart-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.cloudcart_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.cloudcart_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1a"
}

output "vpc_id" {
  value = aws_vpc.cloudcart_vpc.id
}
