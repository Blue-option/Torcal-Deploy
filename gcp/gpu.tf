
resource "google_container_node_pool" "gpu_nodes" {
  name     = "gpu-node-pool"
  location = var.region
  cluster  = module.gke.cluster_id

  initial_node_count = var.gpu_min_count

  autoscaling {
    min_node_count = var.gpu_min_count
    max_node_count = var.gpu_max_count
  }

  // Especifica las zonas específicas que tienen GPU disponible
  node_locations = var.gpu_zones

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.gpu_machine_type
    disk_size_gb = var.gpu_disk_size_gb
    disk_type    = "pd-ssd"

    // Configuración de GPU
    guest_accelerator {
      type  = var.gpu_accelerator_type
      count = var.gpu_accelerator_count
    }

    // Asegura que COS use la configuración correcta para GPU
    image_type = "COS_CONTAINERD"

    // Metadatos de workload para GKE
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    // Etiquetas para identificar nodos con GPU
    labels = {
      "gpu" = "true"
      "cloud.google.com/gke-accelerator" = var.gpu_accelerator_type
    }

    // Taints para evitar que cargas sin tolerations usen estos nodos
    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }

    service_account = var.service_account != "" ? var.service_account : null

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]
  }

  // Añadir un lifecycle ignore_changes para evitar recreación constante
  lifecycle {
    ignore_changes = [
      node_config[0].taint,
      node_config[0].labels,
      node_config[0].metadata,
    ]
  }

  depends_on = [module.gke]
}

// ConfigMap para documentar la configuración de GPU
resource "kubernetes_config_map" "gpu_config" {
  metadata {
    name      = "gpu-config"
    namespace = var.app_namespace
  }

  data = {
    gpu_accelerator_type  = var.gpu_accelerator_type
    gpu_accelerator_count = "${var.gpu_accelerator_count}"
    toleration_key        = "cloud.google.com/gke-accelerator"
    toleration_value      = "present"
    node_selector_key     = "gpu"
    node_selector_value   = "true"
  }

  depends_on = [kubernetes_namespace.app_namespace]
}