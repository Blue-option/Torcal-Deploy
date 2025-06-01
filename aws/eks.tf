# eks.tf - Configuración del cluster EKS

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : ""
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = var.enable_cluster_logging

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
    aws_cloudwatch_log_group.cluster
  ]

  tags = local.common_tags
}

# CloudWatch Log Group for EKS Cluster
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 7

  tags = local.common_tags
}

# EKS Node Group - General Purpose
resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-general"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  version         = var.cluster_version
  
  # AMI type - Amazon Linux 2023
  ami_type = var.general_node_ami_type

  scaling_config {
    desired_size = var.general_node_desired_size
    max_size     = var.general_node_max_size
    min_size     = var.general_node_min_size
  }

  update_config {
    max_unavailable_percentage = 25
  }

  instance_types = var.general_node_instance_types
  
  disk_size = var.general_node_disk_size

  remote_access {
    ec2_ssh_key = aws_key_pair.node_ssh.key_name
    source_security_group_ids = []
  }

  labels = {
    role = "general"
    environment = var.environment
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-general-node"
  })

  # Ensure proper ordering of resource creation
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}

# EKS Node Group - GPU (Optional)
resource "aws_eks_node_group" "gpu" {
  count = var.enable_gpu_nodes ? 1 : 0

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-gpu"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  version         = var.cluster_version
  
  # AMI type for GPU support - Amazon Linux 2023
  ami_type = var.gpu_node_ami_type

  scaling_config {
    desired_size = var.gpu_node_desired_size
    max_size     = var.gpu_node_max_size
    min_size     = var.gpu_node_min_size
  }

  update_config {
    max_unavailable_percentage = 25
  }

  instance_types = var.gpu_node_instance_types
  
  disk_size = var.gpu_node_disk_size

  remote_access {
    ec2_ssh_key = aws_key_pair.node_ssh.key_name
    source_security_group_ids = []
  }

  labels = {
    role = "gpu"
    "nvidia.com/gpu" = "true"
    environment = var.environment
  }

  taint {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-gpu-node"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}

# SSH Key Pair for nodes (optional, for debugging)
resource "tls_private_key" "node_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "node_ssh" {
  key_name   = "${local.cluster_name}-node-ssh"
  public_key = tls_private_key.node_ssh.public_key_openssh

  tags = local.common_tags
}

# Store SSH private key in AWS Secrets Manager
resource "aws_secretsmanager_secret" "node_ssh_key" {
  name                    = "${local.cluster_name}-node-ssh-key"
  description             = "SSH private key for EKS nodes"
  recovery_window_in_days = 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "node_ssh_key" {
  secret_id     = aws_secretsmanager_secret.node_ssh_key.id
  secret_string = tls_private_key.node_ssh.private_key_pem
}

# EKS Addons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  
  resolve_conflicts_on_create = "OVERWRITE"
  
  tags = local.common_tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
  
  resolve_conflicts_on_create = "OVERWRITE"
  
  tags = local.common_tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  
  resolve_conflicts_on_create = "OVERWRITE"
  
  tags = local.common_tags
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"
  
  resolve_conflicts_on_create = "OVERWRITE"
  
  tags = local.common_tags
}