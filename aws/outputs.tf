# Outputs para verificar la conexión
output "account_id" {
  description = "ID de la cuenta AWS"
  value       = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  description = "ARN del usuario/rol actual"
  value       = data.aws_caller_identity.current.arn
}

output "region" {
  description = "Región actual"
  value       = data.aws_region.current.name
}

output "availability_zones" {
  description = "Zonas de disponibilidad en la región"
  value       = data.aws_availability_zones.available.names
}

# Outputs del cluster
output "cluster_endpoint" {
  description = "Endpoint del cluster EKS"
  value       = try(aws_eks_cluster.main.endpoint, "")
}

output "cluster_name" {
  description = "Nombre del cluster EKS"
  value       = var.cluster_name
}

output "cluster_security_group_id" {
  description = "Security group ID del cluster"
  value       = try(aws_eks_cluster.main.vpc_config[0].cluster_security_group_id, "")
}

# Outputs de ArgoCD
output "argocd_server_url" {
  description = "URL del servidor ArgoCD"
  value       = try("http://${data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname}", "")
}

output "argocd_initial_admin_password" {
  description = "Contraseña inicial del admin de ArgoCD"
  value       = try(data.kubernetes_secret.argocd_initial_admin_secret.data.password, "")
  sensitive   = true
}

# Comando para configurar kubectl
output "configure_kubectl" {
  description = "Comando para configurar kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}