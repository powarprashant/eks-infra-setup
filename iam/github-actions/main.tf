terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "cloudcart-terraform-state"
    key            = "iam/github-actions/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────────────────────────────────────
# GitHub OIDC Provider
# There can only be ONE OIDC provider per URL per AWS account. If you already
# have GitHub Actions OIDC set up for another repo, set create_oidc_provider=false
# and this module will use the existing provider via a data source.
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # AWS verifies these automatically; list both current thumbprints for safety
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = var.tags
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = (
    var.create_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : data.aws_iam_openid_connect_provider.github[0].arn
  )
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM Role — GitHub Actions assumes this via OIDC (no static credentials)
# Trust policy is scoped to: any workflow in the specific repo.
# GitHub Environment protection rules enforce human approval for staging/prod.
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict to workflows originating from the specific repo only
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
  description        = "Assumed by GitHub Actions workflows in ${var.github_org}/${var.github_repo}"
  tags               = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM Policy — covers everything Terraform needs to manage this project:
#   EKS, VPC/EC2, IAM (for IRSA roles), KMS, CloudWatch Logs, ECR,
#   S3 + DynamoDB for Terraform state, STS for identity verification.
# ─────────────────────────────────────────────────────────────────────────────
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_actions_permissions" {
  # Terraform remote state — scoped to the project's bucket and lock table
  statement {
    sid    = "TerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
      # Bootstrap permissions (idempotent bucket creation)
      "s3:CreateBucket",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketPublicAccessBlock",
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket}",
      "arn:aws:s3:::${var.state_bucket}/*",
    ]
  }

  statement {
    sid    = "TerraformLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:CreateTable",
      "dynamodb:TagResource",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.lock_table}",
    ]
  }

  # EKS cluster + node group management
  statement {
    sid       = "EKS"
    effect    = "Allow"
    actions   = ["eks:*"]
    resources = ["*"]
  }

  # VPC, subnets, IGW, NAT, route tables, security groups, EIPs
  statement {
    sid       = "EC2VPC"
    effect    = "Allow"
    actions   = ["ec2:*"]
    resources = ["*"]
  }

  # IAM roles/policies for: EKS control plane, node groups, IRSA (vpc-cni, ebs-csi),
  # OIDC provider for IRSA, EKS access entries
  statement {
    sid    = "IAM"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:PassRole",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
      "iam:TagOpenIDConnectProvider",
      "iam:CreateInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["*"]
  }

  # KMS keys for EKS etcd encryption, Flow Logs, CloudWatch Logs
  statement {
    sid       = "KMS"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # EKS control plane logs, VPC Flow Logs
  statement {
    sid       = "CloudWatchLogs"
    effect    = "Allow"
    actions   = ["logs:*"]
    resources = ["*"]
  }

  # ECR repositories for container images
  statement {
    sid       = "ECR"
    effect    = "Allow"
    actions   = ["ecr:*"]
    resources = ["*"]
  }

  # Identity verification during pipeline runs
  statement {
    sid       = "STS"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions" {
  name        = "${var.role_name}-policy"
  description = "Permissions for GitHub Actions Terraform workflows in ${var.github_org}/${var.github_repo}"
  policy      = data.aws_iam_policy_document.github_actions_permissions.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}
