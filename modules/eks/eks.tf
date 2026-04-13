##############################################################
# EKS MODULE — Production-grade, Financial Domain
#
# Design decisions:
# - EKS 1.31 (latest stable)
# - API_AND_CONFIG_MAP auth: bootstrap_cluster_creator_admin_permissions
#   grants Jenkins IAM entity cluster-admin automatically —
#   no aws-auth ConfigMap patching needed
# - All 5 control plane log types, 90-day CloudWatch retention + KMS
# - Worker nodes on private subnets only (NAT provides egress)
# - Managed add-ons: vpc-cni (IRSA), coredns, kube-proxy, ebs-csi (IRSA)
# - Bottlerocket AMI (immutable, minimal attack surface)
# - ON_DEMAND capacity (required for financial workloads)
##############################################################

##################################
# CloudWatch Log Group for EKS Control Plane
##################################

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 90
  
  tags = var.tags
}

##################################
# EKS Cluster
##################################

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_endpoint
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  # Modern EKS API authentication — eliminates aws-auth ConfigMap manipulation.
  # bootstrap_cluster_creator_admin_permissions = true grants the IAM entity
  # running terraform (Jenkins) cluster-admin access automatically.
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  tags = merge(var.tags, {
    Name = var.cluster_name
  })

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.eks,
  ]
}

##################################
# OIDC Provider (required for IRSA)
##################################

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "main" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}

##################################
# Security Group for EKS Control Plane
##################################

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS control plane security group - managed by Terraform"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

##################################
# EKS Node Group
# - Private subnets only (NAT provides outbound access to ECR, SSM, etc.)
# - Bottlerocket: immutable OS, minimal attack surface, no SSH by default
# - ON_DEMAND: financial workloads must not be interrupted
##################################

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-workers"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = var.node_instance_types
  ami_type       = "BOTTLEROCKET_x86_64"
  disk_size      = var.node_disk_size
  capacity_type  = "ON_DEMAND"

  labels = {
    role        = "worker"
    environment = var.environment
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-workers"
  })

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_ssm,
  ]
}

##################################
# Managed Add-ons
# Must be installed after the node group is ready.
# vpc-cni and ebs-csi use IRSA for least-privilege AWS access.
##################################

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.vpc_cni.arn

  tags       = var.tags
  depends_on = [aws_eks_node_group.workers]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags       = var.tags
  depends_on = [aws_eks_node_group.workers]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags       = var.tags
  depends_on = [aws_eks_node_group.workers]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn

  tags       = var.tags
  depends_on = [aws_eks_node_group.workers]
}
