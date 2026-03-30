############################
# EKS Cluster
############################

resource "aws_eks_cluster" "cloudcart_eks" {

  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn
  version  = "1.31"

  vpc_config {
    subnet_ids              = concat(var.public_subnet, var.private_subnet)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
  }

  ###################################
  # KMS Encryption for Kubernetes Secrets
  ###################################

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }

    resources = ["secrets"]
  }

  ###################################
  # Enable Control Plane Logs
  ###################################

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  tags = var.tags
}

############################
# OIDC Provider (for IRSA)
############################

data "tls_certificate" "eks" {
  url = aws_eks_cluster.cloudcart_eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cloudcart_eks.identity[0].oidc[0].issuer

  tags = var.tags
}

############################
# EKS Node Group
############################

resource "aws_eks_node_group" "cloudcart_nodes" {

  cluster_name    = aws_eks_cluster.cloudcart_eks.name
  node_group_name = "cloudcart-workers"
  node_role_arn   = aws_iam_role.node_role.arn

  subnet_ids = var.private_subnet

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  ami_type = "BOTTLEROCKET_x86_64"

  disk_size = 20

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "worker"
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_policy,
  ]
}

############################
# Security Group for EKS
############################

resource "aws_security_group" "eks_cluster_sg" {

  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}