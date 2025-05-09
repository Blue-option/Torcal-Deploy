output "cluster_name" {
  value = var.cluster_name
}

output "cluster_endpoint" {
  value = module.gke.endpoint
}

output "cluster_ca_certificate" {
  value     = module.gke.ca_certificate
  sensitive = true
}

output "argocd_server_url" {
  value = "https://${data.kubernetes_service.argocd_server.status.0.load_balancer.0.ingress.0.ip}"
}

output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

// Para generar el archivo kubeconfig
resource "local_file" "kubeconfig" {
  content = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name = var.cluster_name,
    endpoint     = module.gke.endpoint,
    cluster_ca   = module.gke.ca_certificate,
    token        = data.google_client_config.default.access_token
  })
  filename = "${path.module}/kubeconfig"
}

output "kubernetes_endpoint" {
  description = "Endpoint GKE"
  value       = module.gke.endpoint
  sensitive   = true
}

output "argocd_ip" {
  description = "IP externa de ArgoCD"
  value       = data.kubernetes_service.argocd_server.status.0.load_balancer.0.ingress.0.ip
}



