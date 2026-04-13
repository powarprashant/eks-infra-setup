##############################################################
# VPC MODULE — Production-grade, Financial Domain
#
# Design decisions:
# - 3 Availability Zones for high availability
# - One NAT Gateway per AZ (if one AZ fails, other AZ nodes
#   retain outbound connectivity — critical for financial SLAs)
# - All required EKS subnet discovery tags (ALB/NLB auto-discovery)
# - VPC Flow Logs with KMS encryption (compliance requirement)
# - DNS hostnames enabled (required for EKS node registration)
##############################################################

data "aws_availability_zones" "available" {
  state = "available"
}

##################################
# VPC
##################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.vpc_name
  })
}

##################################
# Internet Gateway
##################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-igw"
  })
}

##################################
# Public Subnets (one per AZ)
# - Used by: ALB/NLB, NAT Gateways
# - EKS tag: elb (internet-facing load balancers)
##################################

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                        = "${var.vpc_name}-public-${count.index}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

##################################
# Private Subnets (one per AZ)
# - Used by: EKS worker nodes, pods
# - EKS tag: internal-elb (internal load balancers)
##################################

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name                                        = "${var.vpc_name}-private-${count.index}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

##################################
# Elastic IPs for NAT Gateways (one per AZ)
##################################

resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-nat-eip-${count.index}"
  })

  depends_on = [aws_internet_gateway.main]
}

##################################
# NAT Gateways (one per AZ — HA)
# Each private subnet routes to its own AZ-local NAT Gateway.
# If AZ-a fails, AZ-b and AZ-c pods are unaffected.
##################################

resource "aws_nat_gateway" "main" {
  count = length(var.public_subnet_cidrs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.main]
}

##################################
# Public Route Table
##################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

##################################
# Private Route Tables (one per AZ)
# Each routes to its AZ-local NAT Gateway for HA egress.
##################################

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-private-rt-${count.index}"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

##################################
# VPC Flow Logs — required for financial compliance / audit trail
# Conditional: disabled in dev/staging to reduce cost.
##################################

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/flow-logs/${var.vpc_name}"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn != "" ? var.kms_key_arn : null

  tags = var.tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.vpc_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.vpc_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-flow-log"
  })
}
