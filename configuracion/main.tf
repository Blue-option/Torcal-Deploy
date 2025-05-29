provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

# Obtener información del clúster GKE existente
data "google_container_cluster" "my_cluster" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id
  
}

# Configurar el proveedor de Kubernetes usando credenciales directas
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.my_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate)
}

# Ahora puedes crear tu recurso de ArgoCD Application
resource "kubernetes_manifest" "argocd_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.app_name
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.repo_revision
        path           = var.repo_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.app_namespace
      }
      syncPolicy = {
        automated = {
          prune     = true
          selfHeal  = true
          allowEmpty = false
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
}

