output "vpc_id" {
description = "VPC ID"
value       = aws_vpc.cloudcart_vpc.id
}

output "public_subnet" {
description = "Public subnet IDs"
value       = aws_subnet.public[*].id
}

output "private_subnet" {
description = "Private subnet IDs"
value       = aws_subnet.private[*].id
}
