#!/bin/bash

# Script para eliminar TODOS los recursos AWS creados con Terraform
# Incluye limpieza manual de recursos que pueden quedar huérfanos

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}================================================${NC}"
echo -e "${RED}ADVERTENCIA: ELIMINACIÓN TOTAL DE RECURSOS AWS${NC}"
echo -e "${RED}================================================${NC}"
echo ""
echo -e "${YELLOW}Este script eliminará PERMANENTEMENTE:${NC}"
echo "- Cluster EKS y todos sus nodos"
echo "- Roles y políticas IAM"
echo "- VPC, subnets, y componentes de red"
echo "- Load Balancers"
echo "- Volúmenes EBS"
echo "- Todos los recursos gestionados por Terraform"
echo ""
echo -e "${RED}¡ESTA ACCIÓN ES IRREVERSIBLE!${NC}"
echo ""

# Confirmación
read -p "¿Estás ABSOLUTAMENTE SEGURO? (escribe 'ELIMINAR TODO' para confirmar): " response
if [ "$response" != "ELIMINAR TODO" ]; then
    echo "Operación cancelada."
    exit 0
fi

# Segunda confirmación
echo ""
echo -e "${RED}ÚLTIMA OPORTUNIDAD: ¿Realmente quieres eliminar TODO?${NC}"
read -p "Escribe 'SI ELIMINAR' para proceder: " response2
if [ "$response2" != "SI ELIMINAR" ]; then
    echo "Operación cancelada."
    exit 0
fi

echo ""
echo -e "${GREEN}Iniciando proceso de eliminación...${NC}"
echo ""

# Función para manejar errores y continuar
try_delete() {
    echo -e "${GREEN}$1${NC}"
    eval "$2" || echo -e "${YELLOW}Nota: $1 - Puede que ya esté eliminado o no exista${NC}"
}

# 1. Primero intentar con Terraform destroy si el estado existe
if [ -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}=== Paso 1: Ejecutando terraform destroy ===${NC}"
    terraform destroy -auto-approve || echo -e "${YELLOW}Terraform destroy falló parcialmente, continuando con limpieza manual...${NC}"
else
    echo -e "${YELLOW}No se encontró terraform.tfstate, procediendo con limpieza manual${NC}"
fi

# 2. Obtener información del proyecto
CLUSTER_NAME="torcal-ml-eks-cluster"
PROJECT_NAME="torcal-ml"
REGION=$(aws configure get region || echo "eu-west-1")

echo ""
echo -e "${YELLOW}=== Paso 2: Limpieza manual de recursos ===${NC}"
echo "Región: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo ""

# 3. Eliminar el cluster EKS y sus componentes
echo -e "${YELLOW}=== Eliminando cluster EKS ===${NC}"

# Primero, eliminar todos los servicios LoadBalancer en el cluster
if aws eks describe-cluster --name $CLUSTER_NAME &>/dev/null; then
    # Configurar kubectl
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION 2>/dev/null || true
    
    # Eliminar servicios LoadBalancer
    echo "Eliminando servicios LoadBalancer..."
    kubectl get svc --all-namespaces -o json | \
    jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' | \
    while read ns name; do
        try_delete "Eliminando servicio LoadBalancer $ns/$name" \
            "kubectl delete svc $name -n $ns --force --grace-period=0"
    done
    
    # Eliminar PVCs
    echo "Eliminando PersistentVolumeClaims..."
    kubectl get pvc --all-namespaces -o json | \
    jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | \
    while read ns name; do
        try_delete "Eliminando PVC $ns/$name" \
            "kubectl delete pvc $name -n $ns --force --grace-period=0"
    done
fi

# Eliminar node groups
echo ""
echo "Eliminando node groups..."
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --query 'nodegroups' --output text 2>/dev/null || echo "")
if [ ! -z "$NODE_GROUPS" ]; then
    for ng in $NODE_GROUPS; do
        try_delete "Eliminando node group $ng" \
            "aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $ng"
    done
    echo "Esperando a que se eliminen los node groups..."
    sleep 30
fi

# Eliminar addons
echo ""
echo "Eliminando EKS addons..."
ADDONS=$(aws eks list-addons --cluster-name $CLUSTER_NAME --query 'addons' --output text 2>/dev/null || echo "")
if [ ! -z "$ADDONS" ]; then
    for addon in $ADDONS; do
        try_delete "Eliminando addon $addon" \
            "aws eks delete-addon --cluster-name $CLUSTER_NAME --addon-name $addon"
    done
fi

# Eliminar el cluster
echo ""
try_delete "Eliminando cluster EKS" \
    "aws eks delete-cluster --name $CLUSTER_NAME"

# 4. Eliminar roles IAM
echo ""
echo -e "${YELLOW}=== Eliminando roles IAM ===${NC}"
IAM_ROLES=(
    "${CLUSTER_NAME}-cluster-role"
    "${CLUSTER_NAME}-node-role"
    "${CLUSTER_NAME}-aws-load-balancer-controller"
    "${CLUSTER_NAME}-ebs-csi-driver"
)

for role in "${IAM_ROLES[@]}"; do
    if aws iam get-role --role-name $role &>/dev/null; then
        # Desconectar políticas
        POLICIES=$(aws iam list-attached-role-policies --role-name $role --query 'AttachedPolicies[*].PolicyArn' --output text 2>/dev/null || echo "")
        for policy in $POLICIES; do
            try_delete "Desconectando política $policy de $role" \
                "aws iam detach-role-policy --role-name $role --policy-arn $policy"
        done
        
        # Eliminar políticas inline
        INLINE_POLICIES=$(aws iam list-role-policies --role-name $role --query 'PolicyNames' --output text 2>/dev/null || echo "")
        for policy in $INLINE_POLICIES; do
            try_delete "Eliminando política inline $policy de $role" \
                "aws iam delete-role-policy --role-name $role --policy-name $policy"
        done
        
        # Eliminar el rol
        try_delete "Eliminando rol $role" \
            "aws iam delete-role --role-name $role"
    fi
done

# Eliminar OIDC provider
echo ""
echo "Eliminando OIDC provider..."
OIDC_PROVIDERS=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[*].Arn' --output text 2>/dev/null || echo "")
for provider in $OIDC_PROVIDERS; do
    if [[ $provider == *"$CLUSTER_NAME"* ]] || [[ $provider == *"eks"* ]]; then
        try_delete "Eliminando OIDC provider" \
            "aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $provider"
    fi
done

# 5. Eliminar recursos de red
echo ""
echo -e "${YELLOW}=== Eliminando recursos de red ===${NC}"

# Buscar VPC por tags
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || echo "")

if [ "$VPC_ID" != "" ] && [ "$VPC_ID" != "None" ]; then
    echo "VPC encontrada: $VPC_ID"
    
    # Eliminar Load Balancers
    echo "Buscando Load Balancers..."
    # Classic Load Balancers
    aws elb describe-load-balancers --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text | \
    tr '\t' '\n' | while read lb; do
        if [ ! -z "$lb" ]; then
            try_delete "Eliminando Classic LB $lb" \
                "aws elb delete-load-balancer --load-balancer-name $lb"
        fi
    done
    
    # Application/Network Load Balancers
    aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' --output text | \
    tr '\t' '\n' | while read lb_arn; do
        if [ ! -z "$lb_arn" ]; then
            try_delete "Eliminando ALB/NLB" \
                "aws elbv2 delete-load-balancer --load-balancer-arn $lb_arn"
        fi
    done
    
    # Esperar un poco para que se eliminen los LBs
    sleep 30
    
    # Eliminar NAT Gateways
    echo ""
    echo "Eliminando NAT Gateways..."
    NAT_GATEWAYS=$(aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
        --query 'NatGateways[*].NatGatewayId' \
        --output text)
    
    for nat in $NAT_GATEWAYS; do
        try_delete "Eliminando NAT Gateway $nat" \
            "aws ec2 delete-nat-gateway --nat-gateway-id $nat"
    done
    
    # Liberar Elastic IPs
    echo ""
    echo "Liberando Elastic IPs..."
    EIPS=$(aws ec2 describe-addresses \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-nat-eip-*" \
        --query 'Addresses[*].AllocationId' \
        --output text)
    
    for eip in $EIPS; do
        try_delete "Liberando EIP $eip" \
            "aws ec2 release-address --allocation-id $eip"
    done
    
    # Esperar a que se eliminen los NAT Gateways
    if [ ! -z "$NAT_GATEWAYS" ]; then
        echo "Esperando a que se eliminen los NAT Gateways..."
        sleep 60
    fi
    
    # Eliminar Internet Gateway
    echo ""
    echo "Eliminando Internet Gateway..."
    IGW=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text)
    
    if [ "$IGW" != "None" ] && [ ! -z "$IGW" ]; then
        try_delete "Desconectando IGW de VPC" \
            "aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID"
        try_delete "Eliminando IGW" \
            "aws ec2 delete-internet-gateway --internet-gateway-id $IGW"
    fi
    
    # Eliminar subnets
    echo ""
    echo "Eliminando subnets..."
    SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets[*].SubnetId' \
        --output text)
    
    for subnet in $SUBNETS; do
        try_delete "Eliminando subnet $subnet" \
            "aws ec2 delete-subnet --subnet-id $subnet"
    done
    
    # Eliminar route tables
    echo ""
    echo "Eliminando route tables..."
    ROUTE_TABLES=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'RouteTables[?Associations[0].Main != `true`].RouteTableId' \
        --output text)
    
    for rt in $ROUTE_TABLES; do
        try_delete "Eliminando route table $rt" \
            "aws ec2 delete-route-table --route-table-id $rt"
    done
    
    # Eliminar security groups
    echo ""
    echo "Eliminando security groups..."
    SECURITY_GROUPS=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'SecurityGroups[?GroupName != `default`].GroupId' \
        --output text)
    
    for sg in $SECURITY_GROUPS; do
        try_delete "Eliminando security group $sg" \
            "aws ec2 delete-security-group --group-id $sg"
    done
    
    # Finalmente, eliminar la VPC
    echo ""
    try_delete "Eliminando VPC $VPC_ID" \
        "aws ec2 delete-vpc --vpc-id $VPC_ID"
fi

# 6. Eliminar volúmenes EBS huérfanos
echo ""
echo -e "${YELLOW}=== Eliminando volúmenes EBS ===${NC}"
VOLUMES=$(aws ec2 describe-volumes \
    --filters "Name=status,Values=available" \
    --query 'Volumes[*].VolumeId' \
    --output text)

for vol in $VOLUMES; do
    try_delete "Eliminando volumen $vol" \
        "aws ec2 delete-volume --volume-id $vol"
done

# 7. Limpiar estado de Terraform
echo ""
echo -e "${YELLOW}=== Limpiando estado de Terraform ===${NC}"
rm -f terraform.tfstate*
rm -f .terraform.lock.hcl
rm -rf .terraform/

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Limpieza completada${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Recursos eliminados:"
echo "✓ Cluster EKS y node groups"
echo "✓ Roles y políticas IAM"
echo "✓ VPC y componentes de red"
echo "✓ Load Balancers"
echo "✓ Volúmenes EBS"
echo "✓ Estado de Terraform"
echo ""
echo -e "${YELLOW}Nota: Algunos recursos pueden tardar unos minutos en eliminarse completamente.${NC}"
echo -e "${YELLOW}Puedes verificar en la consola AWS que todo se haya eliminado.${NC}"