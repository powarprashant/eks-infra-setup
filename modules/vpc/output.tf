output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (one per AZ) — used by ALB/NLB and NAT Gateways"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (one per AZ) — used by EKS worker nodes"
  value       = aws_subnet.private[*].id
}
