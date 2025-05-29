# Configuración específica del proyecto
aws_region   = "eu-west-1"  # Irlanda (más barato que Frankfurt)
project_name = "torcal-ml"
environment  = "production"

# Configuración del cluster
cluster_name    = "torcal-ml-eks-cluster"
cluster_version = "1.32"

# Configuración de red
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Nodos generales (equivalente a e2-standard-8 de GCP)
node_group_name     = "general-nodes"
node_instance_types = ["m5.2xlarge"]  # 8 vCPUs, 32 GB RAM
min_size            = 1
max_size            = 3
desired_size        = 1

# Nodos GPU (equivalente a g2-standard-8 con nvidia-l4)
gpu_node_group_name = "gpu-nodes"
gpu_instance_types  = ["g6.2xlarge"]  # 1 GPU NVIDIA T4, 8 vCPUs, 32 GB RAM
gpu_min_size        = 0
gpu_max_size        = 1

# Aplicación
app_namespace = "torcal-ml"