variable "project_id" {
  description = "ID del proyecto de Google Cloud"
  type        = string
}

variable "region" {
  description = "Región de Google Cloud"
  type        = string
}

variable "kubeconfig_path" {
  description = "Ruta al archivo kubeconfig generado en la etapa 1"
  type        = string
  default     = "../etapa1-infraestructura/kubeconfig"
}

variable "app_name" {
  description = "Nombre de la aplicación ArgoCD"
  type        = string
  default     = "mi-aplicacion"
}

variable "app_namespace" {
  description = "Namespace para la aplicación"
  type        = string
  default     = "torcal-ml-ns"
}

variable "repo_url" {
  description = "URL del repositorio Git con los manifiestos de Kubernetes"
  type        = string
}

variable "repo_revision" {
  description = "Revisión del repositorio a desplegar"
  type        = string
  default     = "main"
}

variable "repo_path" {
  description = "Ruta a los manifiestos de Kubernetes en el repositorio"
  type        = string
  default     = "manifest"
}

variable "cluster_name" {
  description = "Nombre del clúster GKE"
  type        = string
  default     = "torcal-ml-cluster"
}