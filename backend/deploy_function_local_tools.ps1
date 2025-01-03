# Deploy function app using local tools with Key Vault integration
param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = "dev"
)

# Function to handle errors
function Write-ErrorAndExit {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

# Verify Azure CLI is logged in
$loginStatus = az account show 2>$null
if (-not $?) {
    Write-Host "Not logged in to Azure. Initiating login..."
    az login
    if (-not $?) { Write-ErrorAndExit "Failed to login to Azure" }
}

Write-Host "Getting Key Vault and Function App information..."

# Get Key Vault name
$keyVaultName = az keyvault list --resource-group $ResourceGroupName --query "[0].name" -o tsv
if (-not $keyVaultName) {
    Write-ErrorAndExit "Could not find Key Vault in resource group $ResourceGroupName"
}
Write-Host "Found Key Vault: $keyVaultName"

# Get Function App name
$functionAppName = az functionapp list --resource-group $ResourceGroupName --query "[0].name" -o tsv
if (-not $functionAppName) {
    Write-ErrorAndExit "Could not find Function App in resource group $ResourceGroupName"
}
Write-Host "Found Function App: $functionAppName"

# Get storage account name
$storageAccountName = az storage account list --resource-group $ResourceGroupName --query "[0].name" -o tsv
if (-not $storageAccountName) {
    Write-ErrorAndExit "Could not find Storage Account in resource group $ResourceGroupName"
}
Write-Host "Found Storage Account: $storageAccountName"

# Get storage account key and build connection string as backup
$storageKey = az storage account keys list --resource-group $ResourceGroupName --account-name $storageAccountName --query "[0].value" -o tsv
$backupStorageConn = "DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageKey};EndpointSuffix=core.windows.net"

# Get storage connection string from Key Vault
Write-Host "Retrieving storage connection string from Key Vault..."
$storageConn = az keyvault secret show --vault-name $keyVaultName --name "AzureWebJobsStorage" --query "value" -o tsv
if (-not $?) {
    Write-Host "Failed to get connection string from Key Vault, falling back to direct storage account access..."
    $storageConn = $backupStorageConn
} else {
    Write-Host "Successfully retrieved connection string from Key Vault"
}

# Validate storage connection string format
Write-Host "Validating storage connection string..."
if (-not $storageConn.StartsWith("DefaultEndpointsProtocol=")) {
    Write-Host "Invalid connection string format, falling back to direct storage account access..."
    $storageConn = $backupStorageConn
}

# Test storage connection using Azure CLI
Write-Host "Testing storage connection..."
try {
    # Extract account name from connection string
    $accountNameMatch = [regex]::Match($storageConn, "AccountName=([^;]+)")
    if (-not $accountNameMatch.Success) {
        throw "Could not extract account name from connection string"
    }
    $accountName = $accountNameMatch.Groups[1].Value
    
    # Test access by listing containers
    $containers = az storage container list --account-name $accountName --connection-string $storageConn --query "[].name" -o tsv 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list containers: $containers"
    }
    Write-Host "Storage connection test successful"
}
catch {
    Write-Host "Error testing storage connection: $_"
    Write-ErrorAndExit "Failed to validate storage connection string"
}

# Backup existing local.settings.json
Write-Host "Backing up local.settings.json..."
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
if (Test-Path local.settings.json) {
    Copy-Item local.settings.json "local.settings.backup.$timestamp.json" -Force
}

# Update local.settings.json with the storage connection string
Write-Host "Updating local.settings.json with storage connection string..."
$settings = Get-Content local.settings.json | ConvertFrom-Json

# Try Key Vault connection string first, fall back to direct connection string if needed
if ($storageConn.StartsWith("DefaultEndpointsProtocol=")) {
    Write-Host "Using storage connection string from Key Vault"
    $settings.Values.AzureWebJobsStorage = $storageConn
} else {
    Write-Host "Using backup storage connection string"
    $settings.Values.AzureWebJobsStorage = $backupStorageConn
}
$settings | ConvertTo-Json -Depth 10 | Set-Content local.settings.json

# Verify Azure Functions Core Tools is installed
Write-Host "Checking for Azure Functions Core Tools..."
$funcVersion = func --version 2>&1
if (-not $?) {
    Write-Host "Azure Functions Core Tools not found. Installing..."
    npm install -g azure-functions-core-tools@4 --unsafe-perm true
    if (-not $?) {
        Write-ErrorAndExit "Failed to install Azure Functions Core Tools"
    }
}

# Deploy the function app
Write-Host "Deploying function app..."
try {
    func azure functionapp publish $functionAppName --publish-local-settings -i --force
    if (-not $?) {
        throw "Deployment failed"
    }
}
catch {
    Write-ErrorAndExit "Error during deployment: $_"
}

# Restore original local.settings.json
Write-Host "Restoring original local.settings.json..."
if (Test-Path "local.settings.backup.$timestamp.json") {
    Copy-Item "local.settings.backup.$timestamp.json" local.settings.json -Force
    Remove-Item "local.settings.backup.$timestamp.json"
}

Write-Host "Deployment completed successfully!"