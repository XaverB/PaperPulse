# Parameters - use the same values from your deployment
$ENV_NAME = "dev"
$RESOURCE_GROUP_NAME = "rg-${ENV_NAME}"

Write-Host "Starting cleanup of resources..."

# Get Key Vault name before deletion
$keyVaultName = az keyvault list --resource-group $RESOURCE_GROUP_NAME --query "[0].name" -o tsv
Write-Host "Found Key Vault: $keyVaultName"

# Get Document Intelligence (Form Recognizer) account name
$formRecognizerName = az cognitiveservices account list --resource-group $RESOURCE_GROUP_NAME --query "[?kind=='FormRecognizer'].name | [0]" -o tsv
Write-Host "Found Document Intelligence service: $formRecognizerName"

# Get APIM name
$apimName = az apim list --resource-group $RESOURCE_GROUP_NAME --query "[0].name" -o tsv
Write-Host "Found API Management service: $apimName"

# Delete the resource group and all resources in it
Write-Host "Deleting resource group: $RESOURCE_GROUP_NAME"
az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait

# Wait for resource group deletion to complete
Write-Host "Waiting for resource group deletion to complete..."
az group wait --name $RESOURCE_GROUP_NAME --deleted

# Purge Key Vault (required since soft-delete is enabled by default)
if ($keyVaultName) {
    Write-Host "Purging Key Vault: $keyVaultName"
    az keyvault purge --name $keyVaultName
}

# Purge Document Intelligence service
if ($formRecognizerName) {
    Write-Host "Purging Document Intelligence service: $formRecognizerName"
    az cognitiveservices account purge --name $formRecognizerName --location eastus --resource-group $RESOURCE_GROUP_NAME
}

Write-Host "Cleanup completed!"