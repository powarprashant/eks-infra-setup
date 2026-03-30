data "aws_availability_zones" "available" {}

############################

# VPC

############################
resource "aws_vpc" "cloudcart_vpc" {
cidr_block = var.vpc_cidr

tags = merge(var.tags, {
Name = var.vpc_name
})
}

############################

# Internet Gateway

############################
resource "aws_internet_gateway" "igw" {
vpc_id = aws_vpc.cloudcart_vpc.id

tags = merge(var.tags, {
Name = "${var.vpc_name}-igw"
})
}

############################

# Public Subnets

############################
resource "aws_subnet" "public" {
count = length(var.public_subnet_cidrs)

vpc_id                  = aws_vpc.cloudcart_vpc.id
cidr_block              = var.public_subnet_cidrs[count.index]
availability_zone       = var.availability_zones[count.index]
map_public_ip_on_launch = true

tags = merge(var.tags, {
Name = "${var.vpc_name}-public-${count.index}"
})
}

############################

# Private Subnets

############################
resource "aws_subnet" "private" {
count = length(var.private_subnet_cidrs)

vpc_id            = aws_vpc.cloudcart_vpc.id
cidr_block        = var.private_subnet_cidrs[count.index]
availability_zone = var.availability_zones[count.index]

tags = merge(var.tags, {
Name = "${var.vpc_name}-private-${count.index}"
})
}

############################

# Public Route Table

############################
resource "aws_route_table" "public_rt" {
vpc_id = aws_vpc.cloudcart_vpc.id

route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.igw.id
}

tags = merge(var.tags, {
Name = "${var.vpc_name}-public-rt"
})
}

############################

# Associate Public Subnets

############################
resource "aws_route_table_association" "public_assoc" {
count = length(var.public_subnet_cidrs)

subnet_id      = aws_subnet.public[count.index].id
route_table_id = aws_route_table.public_rt.id
}
