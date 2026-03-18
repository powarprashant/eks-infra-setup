resource "aws_eks_cluster" "cloudcart_eks" {

  name = "cloudcart-eks"

  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [
      var.public_subnet,
      var.private_subnet
    ]
  }

}

resource "aws_eks_node_group" "cloudcart_nodes" {

  cluster_name = aws_eks_cluster.cloudcart_eks.name
  node_group_name = "cloudcart-workers"

  node_role_arn = aws_iam_role.node_role.arn

  subnet_ids = [var.private_subnet]

  scaling_config {
    desired_size = 2
    max_size = 2
    min_size = 1
  }

  instance_types = ["t3.medium"]

}