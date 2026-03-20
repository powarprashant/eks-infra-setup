data "aws_availability_zones" "available" {}

resource "aws_vpc" "cloudcart_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "cloudcart-vpc"
  }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id     = aws_vpc.cloudcart_vpc.id
  cidr_block = cidrsubnet(aws_vpc.cloudcart_vpc.cidr_block, 8, count.index)

  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "cloudcart-public-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count = 2

  vpc_id     = aws_vpc.cloudcart_vpc.id
  cidr_block = cidrsubnet(aws_vpc.cloudcart_vpc.cidr_block, 8, count.index + 10)

  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "cloudcart-private-${count.index}"
  }
}