output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.cloudcart_vpc.id
}

output "public_subnet" {
  value = aws_subnet.public[*].id
}

output "private_subnet" {
  value = aws_subnet.private[*].id
}