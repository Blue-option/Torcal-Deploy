# 1. Crear namespace
kubectl create namespace argocd

# 2. Instalar ArgoCD usando el manifiesto oficial
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Esperar a que todos los pods estén listos
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=argocd -n argocd --timeout=300s

# 4. Cambiar el servicio a LoadBalancer para acceso externo
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# 5. Obtener la contraseña inicial del admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# 6. Obtener la URL del LoadBalancer (esperar 2-3 minutos)
kubectl get svc argocd-server -n argocd