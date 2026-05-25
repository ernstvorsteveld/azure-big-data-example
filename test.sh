SUB_ID="96e32d33-5d8d-4f8b-936b-17e1d2c06b3b"

echo "1. Creating Free-Tier Storage Account & Blob Architecture..."
# Force subscription on the group
az group create --name $RG_NAME --location $LOCATION --subscription "$SUB_ID" -o table

# Force subscription explicitly on the storage account creation
az storage account create --name $STORAGE_ACCOUNT --resource-group $RG_NAME --location $LOCATION --sku Standard_LRS --kind StorageV2 --subscription "$SUB_ID" -o table

# Force subscription explicitly when retrieving keys
STORAGE_KEY=$(az storage account keys list --resource-group $RG_NAME --account-name $STORAGE_ACCOUNT --subscription "$SUB_ID" --query "[0].value" -o tsv)

echo "2. Building Blob Storage Container..."
# Force subscription explicitly when creating the container
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY --subscription "$SUB_ID" -o table
