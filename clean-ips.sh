#!/bin/bash
# Script para eliminar todos los recursos GCP que consumen IPs externas

echo "==== SCRIPT PARA LIBERAR IPS EN GCP ===="
echo "ADVERTENCIA: Este script eliminará los balanceadores de carga y liberará IPs."
echo "Asegúrate de tener backups y acceso alternativo a tus servicios."
read -p "¿Continuar? (y/n): " confirm
if [[ $confirm != "y" ]]; then
  echo "Operación cancelada."
  exit 1
fi

# Establece la región
REGION="europe-west4"
echo "Usando región: $REGION"

# 1. Eliminar forwarding rules (libera las IPs)
echo -e "\nPaso 1: Eliminando reglas de reenvío (forwarding rules)..."
FORWARDING_RULES=$(gcloud compute forwarding-rules list --filter="region:($REGION)" --format="value(name)")

if [ -z "$FORWARDING_RULES" ]; then
  echo "No se encontraron reglas de reenvío para eliminar."
else
  for rule in $FORWARDING_RULES; do
    echo "Eliminando regla: $rule"
    gcloud compute forwarding-rules delete $rule --region=$REGION --quiet
  done
fi

# 2. Eliminar target pools
echo -e "\nPaso 2: Eliminando target pools..."
TARGET_POOLS=$(gcloud compute target-pools list --filter="region:($REGION)" --format="value(name)")

if [ -z "$TARGET_POOLS" ]; then
  echo "No se encontraron target pools para eliminar."
else
  for pool in $TARGET_POOLS; do
    echo "Eliminando target pool: $pool"
    gcloud compute target-pools delete $pool --region=$REGION --quiet
  done
fi

# 3. Eliminar health checks asociados
echo -e "\nPaso 3: Eliminando health checks..."
HEALTH_CHECKS=$(gcloud compute http-health-checks list --format="value(name)")

if [ -z "$HEALTH_CHECKS" ]; then
  echo "No se encontraron health checks para eliminar."
else
  for check in $HEALTH_CHECKS; do
    echo "Eliminando health check: $check"
    gcloud compute http-health-checks delete $check --quiet
  done
fi

# 4. Liberar direcciones IP estáticas reservadas
echo -e "\nPaso 4: Liberando direcciones IP estáticas..."
ADDRESSES=$(gcloud compute addresses list --filter="region:($REGION)" --format="value(name)")

if [ -z "$ADDRESSES" ]; then
  echo "No se encontraron direcciones IP estáticas para liberar."
else
  for addr in $ADDRESSES; do
    echo "Liberando dirección IP: $addr"
    gcloud compute addresses delete $addr --region=$REGION --quiet
  done
fi

# 5. Cambiar servicios Kubernetes de tipo LoadBalancer a ClusterIP
echo -e "\nPaso 5: Cambiando servicios Kubernetes a ClusterIP..."
if command -v kubectl &> /dev/null; then
  LOADBALANCER_SERVICES=$(kubectl get svc --all-namespaces -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}')
  
  if [ -z "$LOADBALANCER_SERVICES" ]; then
    echo "No se encontraron servicios LoadBalancer para modificar."
  else
    while read -r namespace name; do
      echo "Cambiando servicio $namespace/$name de LoadBalancer a ClusterIP"
      kubectl patch svc $name -n $namespace -p '{"spec": {"type": "ClusterIP"}}'
    done <<< "$LOADBALANCER_SERVICES"
  fi
else
  echo "kubectl no encontrado. Ignorando el paso de servicios Kubernetes."
fi

echo -e "\n==== LIMPIEZA COMPLETADA ===="
echo "Se han liberado las direcciones IP utilizadas en la región $REGION."
echo "Verifica el resultado con: gcloud compute addresses list"