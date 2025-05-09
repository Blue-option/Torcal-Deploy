// Configurar el proveedor de Google Cloud
provider "google" {
  project = var.project_id
  region  = var.region
}

// Configurar el proveedor de Google Kubernetes Engine
provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

// Configurar el proveedor de Helm para instalar Argo CD
provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}
