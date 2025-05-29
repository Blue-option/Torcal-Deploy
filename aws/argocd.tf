# Instalar ArgoCD usando Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.4"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    <<-EOT
    server:
      service:
        type: LoadBalancer
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      
    configs:
      params:
        server.insecure: true
    EOT
  ]

  depends_on = [
    aws_eks_node_group.general,
    helm_release.aws_load_balancer_controller
  ]
}

# Obtener la contraseña inicial de ArgoCD
data "kubernetes_secret" "argocd_initial_admin_secret" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [helm_release.argocd]
}

# Obtener el servicio de ArgoCD para el LoadBalancer
data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "${helm_release.argocd.name}-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [helm_release.argocd]
}