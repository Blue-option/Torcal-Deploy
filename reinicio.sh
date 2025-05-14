#!/bin/bash

# Script para eliminar recursos que generan costos en Google Cloud Platform
# Configurado para la región europe-west4 únicamente
# MANTIENE las imágenes de Google Container Registry
# ADVERTENCIA: Este script eliminará PERMANENTEMENTE recursos de tu proyecto

set -e

# Configuración de región y zonas
REGION="europe-west4"
ZONES=("europe-west4-a" "europe-west4-b" "europe-west4-c")

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}================================================${NC}"
echo -e "${RED}ADVERTENCIA: SCRIPT DE ELIMINACIÓN MASIVA DE GCP${NC}"
echo -e "${RED}================================================${NC}"
echo ""
echo -e "${YELLOW}Región configurada: ${REGION}${NC}"
echo -e "${YELLOW}Zonas: ${ZONES[@]}${NC}"
echo ""
echo -e "${YELLOW}Este script eliminará PERMANENTEMENTE:${NC}"
echo "- Instancias de Compute Engine"
echo "- Balanceadores de carga"
echo "- Direcciones IP reservadas"
echo "- Discos persistentes no conectados"
echo "- Instancias de Cloud SQL"
echo "- Clústeres de Kubernetes (GKE)"
echo "- Funciones de Cloud Functions"
echo "- Servicios de App Engine"
echo "- Buckets de Cloud Storage"
echo -e "${GREEN}✓ Mantendrá: Imágenes de Container Registry${NC}"
echo "- Y otros recursos que generan costos"
echo ""
echo -e "${RED}¡ESTA ACCIÓN ES IRREVERSIBLE!${NC}"
echo ""

# Función para confirmar acción
confirm() {
    read -p "¿Estás ABSOLUTAMENTE SEGURO que quieres continuar? (escribe 'ELIMINAR TODO' para confirmar): " response
    if [ "$response" != "ELIMINAR TODO" ]; then
        echo "Operación cancelada."
        exit 0
    fi
}

# Primera confirmación
confirm

# Obtener el proyecto actual
PROJECT_ID=$(gcloud config get-value project)
echo ""
echo -e "${YELLOW}Proyecto actual: $PROJECT_ID${NC}"
echo ""

# Segunda confirmación con el nombre del proyecto
echo -e "${RED}Vas a eliminar recursos del proyecto: $PROJECT_ID en la región ${REGION}${NC}"
confirm

# Función para intentar eliminar recursos y continuar si hay error
try_delete() {
    echo -e "${GREEN}$1${NC}"
    eval "$2" || echo -e "${YELLOW}Advertencia: No se pudo completar: $1${NC}"
}

echo ""
echo -e "${GREEN}Iniciando eliminación de recursos en ${REGION}...${NC}"
echo ""

# 1. Eliminar instancias de Compute Engine
echo -e "${YELLOW}=== Eliminando instancias de Compute Engine ===${NC}"
for zone in "${ZONES[@]}"; do
    instances=$(gcloud compute instances list --zones=$zone --format="value(name)" 2>/dev/null || echo "")
    if [ ! -z "$instances" ]; then
        for instance in $instances; do
            try_delete "Eliminando instancia $instance en $zone" \
                "gcloud compute instances delete $instance --zone=$zone --quiet"
        done
    fi
done

# 2. Eliminar grupos de instancias
echo -e "${YELLOW}=== Eliminando grupos de instancias ===${NC}"
for zone in "${ZONES[@]}"; do
    groups=$(gcloud compute instance-groups managed list --zones=$zone --format="value(name)" 2>/dev/null || echo "")
    if [ ! -z "$groups" ]; then
        for group in $groups; do
            try_delete "Eliminando grupo de instancias $group en $zone" \
                "gcloud compute instance-groups managed delete $group --zone=$zone --quiet"
        done
    fi
done

# 3. Eliminar balanceadores de carga (globales y regionales)
echo -e "${YELLOW}=== Eliminando balanceadores de carga ===${NC}"
# Backend services regionales
try_delete "Eliminando backend services regionales" \
    "gcloud compute backend-services delete $(gcloud compute backend-services list --regions=$REGION --format='value(name)' 2>/dev/null) --region=$REGION --quiet"

# Health checks regionales
try_delete "Eliminando health checks regionales" \
    "gcloud compute health-checks delete $(gcloud compute health-checks list --regions=$REGION --format='value(name)' 2>/dev/null) --region=$REGION --quiet"

# Forwarding rules regionales
try_delete "Eliminando forwarding rules regionales" \
    "gcloud compute forwarding-rules delete $(gcloud compute forwarding-rules list --regions=$REGION --format='value(name)' 2>/dev/null) --region=$REGION --quiet"

# 4. Eliminar direcciones IP reservadas
echo -e "${YELLOW}=== Eliminando direcciones IP reservadas ===${NC}"
# IPs regionales
regional_ips=$(gcloud compute addresses list --regions=$REGION --format="value(name)" 2>/dev/null || echo "")
if [ ! -z "$regional_ips" ]; then
    try_delete "Eliminando IPs en $REGION" \
        "gcloud compute addresses delete $regional_ips --region=$REGION --quiet"
fi

# 5. Eliminar discos persistentes no conectados
echo -e "${YELLOW}=== Eliminando discos persistentes no conectados ===${NC}"
for zone in "${ZONES[@]}"; do
    disks=$(gcloud compute disks list --zones=$zone --format="value(name)" 2>/dev/null || echo "")
    if [ ! -z "$disks" ]; then
        for disk in $disks; do
            try_delete "Eliminando disco $disk en $zone" \
                "gcloud compute disks delete $disk --zone=$zone --quiet"
        done
    fi
done

# 6. Eliminar instancias de Cloud SQL
echo -e "${YELLOW}=== Eliminando instancias de Cloud SQL ===${NC}"
sql_instances=$(gcloud sql instances list --filter="region:$REGION" --format="value(name)" 2>/dev/null || echo "")
if [ ! -z "$sql_instances" ]; then
    for instance in $sql_instances; do
        try_delete "Eliminando instancia SQL $instance" \
            "gcloud sql instances delete $instance --quiet"
    done
fi

# 7. Eliminar clústeres de Kubernetes (GKE)
echo -e "${YELLOW}=== Eliminando clústeres de GKE ===${NC}"
# Buscar en zonas específicas
for zone in "${ZONES[@]}"; do
    clusters=$(gcloud container clusters list --zone=$zone --format="value(name)" 2>/dev/null || echo "")
    if [ ! -z "$clusters" ]; then
        for cluster in $clusters; do
            try_delete "Eliminando clúster GKE $cluster en $zone" \
                "gcloud container clusters delete $cluster --zone=$zone --quiet"
        done
    fi
done
# También buscar clústeres regionales
regional_clusters=$(gcloud container clusters list --region=$REGION --format="value(name)" 2>/dev/null || echo "")
if [ ! -z "$regional_clusters" ]; then
    for cluster in $regional_clusters; do
        try_delete "Eliminando clúster GKE regional $cluster en $REGION" \
            "gcloud container clusters delete $cluster --region=$REGION --quiet"
    done
fi

# 8. Eliminar Cloud Functions
echo -e "${YELLOW}=== Eliminando Cloud Functions ===${NC}"
functions=$(gcloud functions list --regions=$REGION --format="value(name)" 2>/dev/null || echo "")
if [ ! -z "$functions" ]; then
    for function in $functions; do
        try_delete "Eliminando función $function" \
            "gcloud functions delete $function --region=$REGION --quiet"
    done
fi

# 9. Eliminar servicios de App Engine
echo -e "${YELLOW}=== Eliminando servicios de App Engine ===${NC}"
# App Engine es un servicio global, pero puede tener versiones en regiones específicas
services=$(gcloud app services list --format="value(id)" | grep -v "^default$" 2>/dev/null || echo "")
if [ ! -z "$services" ]; then
    for service in $services; do
        try_delete "Eliminando servicio App Engine $service" \
            "gcloud app services delete $service --quiet"
    done
fi

# 10. Eliminar buckets de Cloud Storage
echo -e "${YELLOW}=== Eliminando buckets de Cloud Storage ===${NC}"
# Filtrar buckets por región
buckets=$(gsutil ls -L -b | grep -A 1 "Location constraint:.*$REGION" | grep "gs://" 2>/dev/null || echo "")
if [ ! -z "$buckets" ]; then
    for bucket in $buckets; do
        try_delete "Eliminando bucket $bucket" \
            "gsutil -m rm -r $bucket"
    done
fi

# 11. MANTENEMOS LAS IMÁGENES DE CONTAINER REGISTRY
echo -e "${GREEN}=== Manteniendo imágenes de Container Registry ===${NC}"
echo "Las imágenes de GCR no serán eliminadas según lo solicitado."

# 12. Eliminar objetos de Firestore (si está habilitado)
echo -e "${YELLOW}=== Eliminando datos de Firestore ===${NC}"
try_delete "Intentando eliminar índices de Firestore" \
    "gcloud firestore indexes composite delete --all-indexes --quiet"

# 13. Eliminar tablas de BigQuery
echo -e "${YELLOW}=== Eliminando datasets de BigQuery ===${NC}"
# BigQuery datasets pueden tener ubicación específica
datasets=$(bq ls -d --format=json | jq -r --arg region "$REGION" '.[] | select(.location == $region) | .datasetReference.datasetId' 2>/dev/null || echo "")
if [ ! -z "$datasets" ]; then
    for dataset in $datasets; do
        try_delete "Eliminando dataset BigQuery $dataset" \
            "bq rm -r -f -d $PROJECT_ID:$dataset"
    done
fi

# 14. Eliminar reglas de firewall personalizadas
echo -e "${YELLOW}=== Eliminando reglas de firewall personalizadas ===${NC}"
firewall_rules=$(gcloud compute firewall-rules list --format="value(name)" | grep -v "^default-" 2>/dev/null || echo "")
if [ ! -z "$firewall_rules" ]; then
    for rule in $firewall_rules; do
        try_delete "Eliminando regla de firewall $rule" \
            "gcloud compute firewall-rules delete $rule --quiet"
    done
fi

# 15. Eliminar subredes personalizadas
echo -e "${YELLOW}=== Eliminando subredes personalizadas ===${NC}"
subnets=$(gcloud compute networks subnets list --regions=$REGION --format="value(name)" | grep -v "^default$" 2>/dev/null || echo "")
if [ ! -z "$subnets" ]; then
    for subnet in $subnets; do
        try_delete "Eliminando subred $subnet en $REGION" \
            "gcloud compute networks subnets delete $subnet --region=$REGION --quiet"
    done
fi

# 16. Eliminar Cloud NAT
echo -e "${YELLOW}=== Eliminando Cloud NAT ===${NC}"
nats=$(gcloud compute routers nats list --router-region=$REGION --format="value(name)" 2>/dev/null || echo "")
if [ ! -z "$nats" ]; then
    for nat in $nats; do
        router=$(gcloud compute routers nats list --router-region=$REGION --filter="name:$nat" --format="value(router)")
        try_delete "Eliminando Cloud NAT $nat" \
            "gcloud compute routers nats delete $nat --router=$router --router-region=$REGION --quiet"
    done
fi

# 17. Eliminar Cloud Routers
echo -e "${YELLOW}=== Eliminando Cloud Routers ===${NC}"
routers=$(gcloud compute routers list --regions=$REGION --format="value(name)" 2>/dev/null || echo "")
if [ ! -z "$routers" ]; then
    for router in $routers; do
        try_delete "Eliminando Cloud Router $router" \
            "gcloud compute routers delete $router --region=$REGION --quiet"
    done
fi

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Limpieza completada para la región ${REGION}${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${GREEN}✓ Las imágenes de Container Registry se han mantenido${NC}"
echo ""
echo "Nota: Algunos recursos pueden tardar en eliminarse completamente."
echo "Revisa la consola de GCP para verificar que todos los recursos fueron eliminados."
echo ""
echo -e "${YELLOW}Recursos globales no eliminados:${NC}"
echo "- Imágenes de Container Registry (mantenidas intencionalmente)"
echo "- Recursos fuera de la región ${REGION}"
echo "- Redes VPC globales (solo se eliminaron las subredes de ${REGION})"