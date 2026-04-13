##############################################################
# EKS IAM — Production-grade, Financial Domain
#
# Roles defined here:
# 1. cluster      — EKS control plane role
# 2. node         — EC2 worker node role (+ SSM for keyless access)
# 3. vpc_cni      — IRSA role for the vpc-cni managed add-on
# 4. ebs_csi      — IRSA role for the aws-ebs-csi-driver managed add-on
#
# Principle of least privilege: IRSA roles (vpc_cni, ebs_csi) scope
# AWS permissions to the exact Kubernetes service account, not the
# entire node role.
##############################################################

locals {
  oidc_issuer = replace(aws_iam_openid_connect_provider.main.url, "https://", "")
}

##################################
# 1. EKS Cluster Role
##################################

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

##################################
# 2. Worker Node Role
##################################

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# SSM access — allows Session Manager shell access without SSH keys.
# Required for financial production (no exposed SSH ports, full audit trail).
resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

##################################
# 3. IRSA — vpc-cni add-on
# Scoped to service account: kube-system/aws-node
##################################

resource "aws_iam_role" "vpc_cni" {
  name = "${var.cluster_name}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.main.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
          "${local.oidc_issuer}:sub" = "system:serviceaccount:kube-system:aws-node"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

##################################
# 4. IRSA — aws-ebs-csi-driver add-on
# Scoped to service account: kube-system/ebs-csi-controller-sa
##################################

resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.main.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
          "${local.oidc_issuer}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

##################################
# 5. Jenkins EKS Access Entry
# Grants the Jenkins pipeline IAM role cluster-admin via the modern
# EKS Access Entry API (authentication_mode = API_AND_CONFIG_MAP).
#
# Why not rely solely on bootstrap_cluster_creator_admin_permissions?
# That flag only covers the exact IAM principal that called CreateCluster.
# If Jenkins uses an assumed-role session, the session ARN != the role ARN
# and EKS rejects kubectl calls with "provide credentials".
# An explicit access entry bound to the role ARN is resilient to this.
##################################

resource "aws_eks_access_entry" "jenkins" {
  count         = var.jenkins_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.jenkins_role_arn
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "jenkins" {
  count         = var.jenkins_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.jenkins_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jenkins]
}
