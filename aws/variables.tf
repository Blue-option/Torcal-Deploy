# Variables generales
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
  default     = "pre-produccion"
}

# Variables de red
variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zonas de disponibilidad a usar"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

# Variables de EKS
variable "cluster_name" {
  description = "Nombre del cluster EKS"
  type        = string
  default     = "torcal-ml-eks-cluster"
}

variable "cluster_version" {
  description = "Versión de Kubernetes para EKS"
  type        = string
  default     = "1.28"
}

# Variables de nodos
variable "node_group_name" {
  description = "Nombre del grupo de nodos"
  type        = string
  default     = "general-nodes"
}

variable "node_instance_types" {
  description = "Tipos de instancia EC2 para los nodos"
  type        = list(string)
  default     = ["m5.2xlarge"]
}

variable "min_size" {
  description = "Número mínimo de nodos"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Número máximo de nodos"
  type        = number
  default     = 1
}

variable "desired_size" {
  description = "Número deseado de nodos"
  type        = number
  default     = 1
}

# Variables para nodos GPU
variable "gpu_node_group_name" {
  description = "Nombre del grupo de nodos GPU"
  type        = string
  default     = "gpu-nodes"
}

variable "gpu_instance_types" {
  description = "Tipos de instancia EC2 con GPU"
  type        = list(string)
  default     = ["g6.2xlarge"] # Similar a g2-standard-8 de GCP
}

variable "gpu_min_size" {
  description = "Número mínimo de nodos GPU"
  type        = number
  default     = 0
}

variable "gpu_max_size" {
  description = "Número máximo de nodos GPU"
  type        = number
  default     = 1
}

# Variables de aplicación
variable "app_namespace" {
  description = "Namespace para la aplicación"
  type        = string
  default     = "torcal-ml"
}