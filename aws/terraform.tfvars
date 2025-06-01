# terraform.tfvars.example - Ejemplo de configuración

# General
aws_region   = "eu-west-1"
project_name = "torcal-ml"
environment  = "pre-production"

# Networking
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-west-1a"]

# EKS Cluster
cluster_version                      = "1.32"  # Última versión estable
enable_cluster_encryption           = true
cluster_endpoint_private_access     = true
cluster_endpoint_public_access      = true
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]  # Restringir en producción

# Node Group - General
general_node_instance_types = ["m7i.2xlarge"]  # 8 vCPUs, 32 GB RAM - última generación
general_node_min_size      = 1
general_node_max_size      = 1
general_node_desired_size  = 1
general_node_disk_size     = 100

# Node Group - GPU
enable_gpu_nodes      = true
gpu_node_instance_types = ["g6.2xlarge"]  # NVIDIA L4 GPU, 8 vCPUs, 32 GB RAM - optimizado para inferencia
gpu_node_min_size      = 0
gpu_node_max_size      = 1
gpu_node_desired_size  = 1
gpu_node_disk_size     = 50

# Security
allowed_cidr_blocks = []  # Añadir IPs permitidas para acceso al cluster

# Monitoring
enable_cluster_logging = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

# Cost Optimization
enable_spot_instances = false
spot_max_price       = ""