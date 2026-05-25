#!/bin/bash

# ==========================================
# VARIABLE DEFINITIONS
# ==========================================
SUB_ID="96e32d33-5d8d-4f8b-936b-17e1d2c06b3b"
RG_NAME="spark-serverless-rg"
LOCATION="westeurope"
CONTAINER_NAME="iceberg-warehouse"

# Collision-safe unique suffix: timestamp + random avoids $RANDOM reuse across runs
SUFFIX=$(date +%s)$RANDOM
STORAGE_ACCOUNT="sparkstore${SUFFIX:0:10}"
ACR_NAME="sparkacr${SUFFIX:0:10}"

echo "=========================================================="
echo " Starting Fresh Serverless Deployment Pipeline (macOS Optimized)"
echo " Target Subscription: $SUB_ID"
echo " Resource Group:      $RG_NAME"
echo " Storage Account:     $STORAGE_ACCOUNT"
echo " Container Registry:  $ACR_NAME"
echo "=========================================================="

# ----------------------------------------
# Internal helper: prints error and returns
# Using "return" instead of "exit" so that
# "source deploy.sh" never kills your terminal
# ----------------------------------------
_fail() {
  echo "ERROR: $1"
  rm -f aci-deployment.tmp.yaml
  return 1
}

# 1. Set active subscription
az account set --subscription "$SUB_ID" || { _fail "az account set failed"; return 1; }

# ----------------------------------------
echo "1. Creating Resource Group & Storage Account..."
# ----------------------------------------
az group create \
  --name "$RG_NAME" \
  --location "$LOCATION" \
  --subscription "$SUB_ID" \
  -o table || { _fail "Resource group creation failed"; return 1; }

az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --subscription "$SUB_ID" \
  -o table || { _fail "Storage account creation failed"; return 1; }

STORAGE_KEY=$(az storage account keys list \
  --resource-group "$RG_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --subscription "$SUB_ID" \
  --query "[0].value" -o tsv) || { _fail "Failed to retrieve storage key"; return 1; }

# ----------------------------------------
echo "2. Building Blob Storage Container..."
# ----------------------------------------
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --subscription "$SUB_ID" \
  -o table || { _fail "Blob container creation failed"; return 1; }

# ----------------------------------------
echo "3. Creating Azure Container Registry & importing spark-iceberg image..."
#    ACR import pulls from Docker Hub server-side — avoids ACI shared-IP rate limits
# ----------------------------------------
az acr create \
  --resource-group "$RG_NAME" \
  --name "$ACR_NAME" \
  --sku Basic \
  --admin-enabled true \
  --subscription "$SUB_ID" \
  -o table || { _fail "ACR creation failed"; return 1; }

echo "   Importing spark-iceberg from Docker Hub into ACR (this takes ~2 min)..."
az acr import \
  --name "$ACR_NAME" \
  --source "docker.io/tabulario/spark-iceberg:3.5.5_1.8.1" \
  --image "spark-iceberg:3.5.5_1.8.1" \
  --subscription "$SUB_ID" || { _fail "ACR image import failed"; return 1; }

ACR_SERVER=$(az acr show \
  --name "$ACR_NAME" \
  --subscription "$SUB_ID" \
  --query loginServer -o tsv) || { _fail "Failed to get ACR server"; return 1; }

ACR_USER=$(az acr credential show \
  --name "$ACR_NAME" \
  --subscription "$SUB_ID" \
  --query username -o tsv) || { _fail "Failed to get ACR username"; return 1; }

ACR_PASS=$(az acr credential show \
  --name "$ACR_NAME" \
  --subscription "$SUB_ID" \
  --query "passwords[0].value" -o tsv) || { _fail "Failed to get ACR password"; return 1; }

echo "   ACR Server: $ACR_SERVER"

# ----------------------------------------
echo "4. Encoding and packaging secrets into configuration manifest..."
# ----------------------------------------
cp aci-deployment.yaml aci-deployment.tmp.yaml || { _fail "Could not copy aci-deployment.yaml — is it in the same directory?"; return 1; }

# macOS base64 line-wrap mitigation: strip newlines to prevent YAML formatting corruption
NGINX_B64=$(base64 < nginx.conf | tr -d '\n')           || { _fail "Could not read nginx.conf"; return 1; }
CA_B64=$(base64 < certs/ca.pem | tr -d '\n')            || { _fail "Could not read certs/ca.pem"; return 1; }
SERVER_CERT_B64=$(base64 < certs/server-cert.pem | tr -d '\n') || { _fail "Could not read certs/server-cert.pem"; return 1; }
SERVER_KEY_B64=$(base64 < certs/server-key.pem | tr -d '\n')   || { _fail "Could not read certs/server-key.pem"; return 1; }

# Inject Azure storage references
perl -pi -e "s/YOUR_BLOB_CONTAINER/$CONTAINER_NAME/g"       aci-deployment.tmp.yaml
perl -pi -e "s/YOUR_STORAGE_ACCOUNT/$STORAGE_ACCOUNT/g"    aci-deployment.tmp.yaml
perl -pi -e "s|YOUR_STORAGE_ACCESS_KEY|$STORAGE_KEY|g"     aci-deployment.tmp.yaml

# Inject ACR image reference and credentials
perl -pi -e "s|ACR_IMAGE_PLACEHOLDER|$ACR_SERVER/spark-iceberg:3.5.5_1.8.1|g" aci-deployment.tmp.yaml
perl -pi -e "s|ACR_SERVER_PLACEHOLDER|$ACR_SERVER|g"       aci-deployment.tmp.yaml
perl -pi -e "s|ACR_USER_PLACEHOLDER|$ACR_USER|g"           aci-deployment.tmp.yaml
perl -pi -e "s|ACR_PASS_PLACEHOLDER|$ACR_PASS|g"           aci-deployment.tmp.yaml

# Inject base64-encoded secrets
perl -pi -e "s/BASE64_NGINX_CONF/$NGINX_B64/g"             aci-deployment.tmp.yaml
perl -pi -e "s/BASE64_CA_PEM/$CA_B64/g"                    aci-deployment.tmp.yaml
perl -pi -e "s/BASE64_SERVER_CERT/$SERVER_CERT_B64/g"      aci-deployment.tmp.yaml
perl -pi -e "s/BASE64_SERVER_KEY/$SERVER_KEY_B64/g"        aci-deployment.tmp.yaml

# ----------------------------------------
echo "5. Launching Serverless Container Group..."
# ----------------------------------------
if ! az container create \
  --resource-group "$RG_NAME" \
  --file aci-deployment.tmp.yaml \
  --subscription "$SUB_ID" \
  -o json; then
  _fail "Container group creation failed"
  return 1
fi

rm -f aci-deployment.tmp.yaml

SERVERLESS_IP=$(az container show \
  --resource-group "$RG_NAME" \
  --name spark-serverless-group \
  --subscription "$SUB_ID" \
  --query "ipAddress.ip" -o tsv)

echo "=========================================================================="
echo " Serverless Infrastructure Running Successfully!"
echo " Secure Serverless Public IP: $SERVERLESS_IP"
echo "=========================================================================="
