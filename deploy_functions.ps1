param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$FunctionAppName
)

# Verify Azure CLI is logged in
$loginStatus = az account show 2>$null
if (-not $?) {
    Write-Host "Not logged in to Azure. Initiating login..."
    az login
}

# Verify the function app exists
Write-Host "Verifying function app exists..."
$functionApp = az functionapp show `
    -g $ResourceGroupName `
    -n $FunctionAppName `
    2>$null

if (-not $?) {
    Write-Error "Function App '$FunctionAppName' not found in Resource Group '$ResourceGroupName'"
    exit 1
}

# Build and publish the function app
Write-Host "Building and publishing function app..."
$publishFolder = "./publish"
if (Test-Path $publishFolder) {
    Remove-Item -Path $publishFolder -Recurse -Force
}

dotnet publish ./backend/backend.csproj `
    -c Release `
    -o $publishFolder

if (-not $?) {
    Write-Error "Failed to build and publish function app"
    exit 1
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
az functionapp deployment source config-zip `
    -g $ResourceGroupName `
    -n $FunctionAppName `
    --src $zipPath

if (-not $?) {
    Write-Error "Failed to deploy function app code"
    exit 1
}

# Clean up
Write-Host "Cleaning up temporary files..."
Remove-Item -Path $publishFolder -Recurse -Force
Remove-Item -Path $zipPath -Force

# Get and display the function app URL
$functionAppUrl = az functionapp show `
    -g $ResourceGroupName `
    -n $FunctionAppName `
    --query "defaultHostName" `
    -o tsv

Write-Host "`nDeployment completed successfully!"
Write-Host "Function App URL: https://$functionAppUrl"