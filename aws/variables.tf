# variables.tf - Variables de configuración
variable "aws_region" {
  description = "Región de AWS donde se desplegarán los recursos"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "torcal-ml"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "El ambiente debe ser: development, staging o production"
  }
}

# Networking
variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zonas de disponibilidad a usar"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

# EKS Cluster
variable "cluster_version" {
  description = "Versión de Kubernetes para EKS"
  type        = string
  default     = "1.32"  # Última versión estable
}

variable "enable_cluster_encryption" {
  description = "Habilitar encriptación del cluster"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Habilitar acceso privado al API del cluster"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Habilitar acceso público al API del cluster"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs permitidos para acceso público"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Node Groups - General
variable "general_node_instance_types" {
  description = "Tipos de instancia EC2 para nodos generales"
  type        = list(string)
  default     = ["m7i.2xlarge"]  # 8 vCPUs, 32 GB RAM - última generación
}

variable "general_node_ami_type" {
  description = "Tipo de AMI para nodos generales"
  type        = string
  default     = "AL2023_x86_64_STANDARD"  # Amazon Linux 2023 recomendado
}

variable "general_node_min_size" {
  description = "Número mínimo de nodos generales"
  type        = number
  default     = 1
}

variable "general_node_max_size" {
  description = "Número máximo de nodos generales"
  type        = number
  default     = 5
}

variable "general_node_desired_size" {
  description = "Número deseado de nodos generales"
  type        = number
  default     = 2
}

variable "general_node_disk_size" {
  description = "Tamaño del disco para nodos generales (GB)"
  type        = number
  default     = 100
}

# Node Groups - GPU
variable "enable_gpu_nodes" {
  description = "Habilitar nodos con GPU"
  type        = bool
  default     = true
}

variable "gpu_node_instance_types" {
  description = "Tipos de instancia EC2 con GPU"
  type        = list(string)
  default     = ["g6.2xlarge"]  # NVIDIA L4 GPU, 8 vCPUs, 32 GB RAM - optimizado para inferencia
}

variable "gpu_node_ami_type" {
  description = "Tipo de AMI para nodos GPU"
  type        = string
  default     = "AL2023_x86_64_NVIDIA"  # Amazon Linux 2023 con soporte GPU
}

variable "gpu_node_min_size" {
  description = "Número mínimo de nodos GPU"
  type        = number
  default     = 0
}

variable "gpu_node_max_size" {
  description = "Número máximo de nodos GPU"
  type        = number
  default     = 2
}

variable "gpu_node_desired_size" {
  description = "Número deseado de nodos GPU"
  type        = number
  default     = 1
}

variable "gpu_node_disk_size" {
  description = "Tamaño del disco para nodos GPU (GB)"
  type        = number
  default     = 200
}

# Security
variable "allowed_cidr_blocks" {
  description = "Bloques CIDR permitidos para acceso al cluster"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "ARN de la llave KMS para encriptación (opcional)"
  type        = string
  default     = ""
}

# Monitoring
variable "enable_cluster_logging" {
  description = "Tipos de logs del cluster a habilitar"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# Cost optimization
variable "enable_spot_instances" {
  description = "Usar instancias spot para nodos generales"
  type        = bool
  default     = false
}

variable "spot_max_price" {
  description = "Precio máximo para instancias spot"
  type        = string
  default     = ""
}