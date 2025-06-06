terraform {
  required_version = ">= 1.5.7"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  
  # Backend para almacenar el estado (opcional pero recomendado)
  # backend "s3" {
  #   bucket = "mi-terraform-state-bucket"
  #   key    = "infraestructura/terraform.tfstate"
  #   region = "eu-west-1"
  # }
}

# Configurar el proveedor de AWS
provider "aws" {
  region = var.aws_region
  
  # Si usas un perfil específico
  # profile = "mi-perfil"
  
  # Tags por defecto para todos los recursos
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# Data source para obtener información de la cuenta
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}