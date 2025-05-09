

// Obtener información de la configuración del cliente de Google
data "google_client_config" "default" {}

// Crear un clúster de GKE
module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google"
  project_id                 = var.project_id
  name                       = var.cluster_name
  region                     = var.region
  zones                      = var.zones
  network                    = var.network
  subnetwork                 = var.subnetwork
  ip_range_pods              = var.ip_range_pods
  ip_range_services          = var.ip_range_services
  http_load_balancing        = true
  network_policy             = true
  horizontal_pod_autoscaling = true
  filestore_csi_driver       = false
  create_service_account     = true
  remove_default_node_pool   = true

  node_pools = [
    {
      name               = "general-node-pool"
      machine_type       = var.machine_type
      min_count          = var.min_node_count
      max_count          = var.max_node_count
      disk_size_gb       = var.disk_size_gb
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
      service_account    = var.service_account
      preemptible        = false
      initial_node_count = var.initial_node_count
    },
  ]
}

// Crear namespace para Argo CD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [module.gke]
}

// Instalar Argo CD usando Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  depends_on = [kubernetes_namespace.argocd]
}


// Crear el namespace para la aplicación
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.app_namespace
  }

  depends_on = [module.gke]
}

// Exportar la dirección IP externa de Argo CD
data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [helm_release.argocd]
}

// Crear namespace para Kafka
resource "kubernetes_namespace" "kafka_system" {
  metadata {
    name = "kafka-system"
  }

  depends_on = [module.gke]
}

// Instalar Kafka usando Helm
resource "helm_release" "kafka" {
  name             = "kafka"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "kafka"
  version          = "20.1.1"  // O la versión que prefieras
  namespace        = kubernetes_namespace.kafka_system.metadata[0].name
  create_namespace = false
  
  values = [
    <<-EOF
    replicaCount: 1
    autoCreateTopicsEnable: true
    deleteTopicEnable: true
    persistence:
      enabled: true
      size: 10Gi
    EOF
  ]

  depends_on = [module.gke]
}

// Crear namespace para KEDA
resource "kubernetes_namespace" "keda" {
  metadata {
    name = "keda"
  }

  depends_on = [module.gke]
}

// Instalar KEDA usando Helm
resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = "2.11.2"  // O la versión que prefieras
  namespace  = kubernetes_namespace.keda.metadata[0].name

  set {
    name  = "crds.install"
    value = "true"
  }

  depends_on = [kubernetes_namespace.keda]
}