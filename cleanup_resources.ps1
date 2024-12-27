# Basic usage with just resource group name
#.\cleanup_resources.ps1 -ResourceGroupName "rg-dev"

# With subscription ID if needed
#.\cleanup_resources.ps1 -ResourceGroupName "rg-dev" -SubscriptionId "your-subscription-id"


param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId
)

# Set subscription if provided
if ($SubscriptionId) {
    Write-Host "Setting subscription context..."
    az account set --subscription $SubscriptionId
}

# Get resource information before deletion
Write-Host "Getting resource information..."
$keyVault = az keyvault list --resource-group $ResourceGroupName --query "[].name" -o tsv
$apimService = az apim list --resource-group $ResourceGroupName --query "[].name" -o tsv
$cognitiveService = az cognitiveservices account list --resource-group $ResourceGroupName --query "[].name" -o tsv

# Delete the resource group and all its resources
Write-Host "Deleting resource group: $ResourceGroupName"
az group delete --name $ResourceGroupName --yes --no-wait

# Wait for resource group deletion to complete
Write-Host "Waiting for resource group deletion to complete..."
do {
    $rgExists = az group exists --name $ResourceGroupName
    if ($rgExists -eq "true") {
        Write-Host "Resource group deletion in progress..."
        Start-Sleep -Seconds 10
    }
} while ($rgExists -eq "true")

# Purge soft-deleted Key Vault
if ($keyVault) {
    Write-Host "Purging soft-deleted Key Vault: $keyVault"
    az keyvault purge --name $keyVault
    Write-Host "Key Vault purged"
}

# Purge soft-deleted APIM instance
if ($apimService) {
    Write-Host "Purging soft-deleted APIM service: $apimService"
    az apim delete --name $apimService --resource-group $ResourceGroupName --yes
    Write-Host "APIM service purged"
}

# Purge soft-deleted Cognitive Services account
if ($cognitiveService) {
    Write-Host "Purging soft-deleted Cognitive Services account: $cognitiveService"
    az cognitiveservices account purge --name $cognitiveService --resource-group $ResourceGroupName --location eastus2
    Write-Host "Cognitive Services account purged"
}

Write-Host "Cleanup completed!"