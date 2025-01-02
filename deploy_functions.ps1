param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$FunctionAppName
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

# Verify the function app exists
Write-Host "Verifying function app exists..."
$functionApp = az functionapp show --resource-group $ResourceGroupName --name $FunctionAppName 2>$null | ConvertFrom-Json
if (-not $functionApp) {
    Write-ErrorAndExit "Function App '$FunctionAppName' not found in Resource Group '$ResourceGroupName'"
}

# Get the storage account details directly
Write-Host "Getting storage account details..."
$storageAccounts = az storage account list --resource-group $ResourceGroupName | ConvertFrom-Json
$storageAccount = $storageAccounts | Select-Object -First 1

if (-not $storageAccount) {
    Write-ErrorAndExit "No storage account found in resource group $ResourceGroupName"
}

# Get storage account key directly
$storageKeys = az storage account keys list --resource-group $ResourceGroupName --account-name $storageAccount.name | ConvertFrom-Json
$storageKey = $storageKeys[0].value

# Temporarily set the storage connection string directly in function app settings
Write-Host "Temporarily setting storage connection string..."
$storageConnectionString = "DefaultEndpointsProtocol=https;AccountName=$($storageAccount.name);AccountKey=$storageKey;EndpointSuffix=core.windows.net"

az functionapp config appsettings set `
    --resource-group $ResourceGroupName `
    --name $FunctionAppName `
    --settings "AzureWebJobsStorage=$storageConnectionString" `
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING=$storageConnectionString" `
    "WEBSITE_CONTENTSHARE=$(${FunctionAppName}.ToLower())"

# Ensure we're in the correct directory
$projectPath = "./backend/backend.csproj"
if (-not (Test-Path $projectPath)) {
    Write-ErrorAndExit "Project file not found at $projectPath"
}

# Build and publish the function app
Write-Host "Building and publishing function app..."
$publishFolder = "./publish"
if (Test-Path $publishFolder) {
    Remove-Item -Path $publishFolder -Recurse -Force
}

# Build with detailed output
dotnet publish $projectPath -c Release -o $publishFolder --verbosity detailed
if (-not $?) {
    Write-ErrorAndExit "Failed to build and publish function app"
}

# Create ZIP file for deployment
Write-Host "Creating deployment package..."
$zipPath = "./function-app.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath
}

Compress-Archive -Path "$publishFolder/*" -DestinationPath $zipPath -Force

# Deploy the function app code
Write-Host "Deploying function app code..."
$deployResult = az functionapp deployment source config-zip `
    --resource-group $ResourceGroupName `
    --name $FunctionAppName `
    --src $zipPath `
    --timeout 180 `
    --build-remote false

if ($LASTEXITCODE -ne 0) {
    Write-Host "Deployment output:" -ForegroundColor Red
    Write-Host $deployResult
    Write-ErrorAndExit "Failed to deploy function app code. See deployment logs for details."
}

# Clean up temporary files
Write-Host "Cleaning up temporary files..."
Remove-Item -Path $publishFolder -Recurse -Force
Remove-Item -Path $zipPath -Force

# Get and display the function app URL
$functionAppUrl = az functionapp show `
    --resource-group $ResourceGroupName `
    --name $FunctionAppName `
    --query "defaultHostName" `
    --output tsv

Write-Host "`nDeployment completed successfully!"
Write-Host "Function App URL: https://$functionAppUrl"

# Show deployment logs
Write-Host "`nChecking recent deployment logs..."
az webapp log deployment show --resource-group $ResourceGroupName --name $FunctionAppName

# Add a pause to show any final messages
Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")