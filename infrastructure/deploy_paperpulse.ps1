# Login to Azure
az login

# Set variables
$ENV_NAME="dev"
$LOCATION="eastus2"

# Get the root directory path (one level up from infrastructure)
$rootDir = Split-Path -Parent $PSScriptRoot

Write-Host "Starting infrastructure deployment..."

# Deploy the infrastructure
$deployment = az deployment sub create `
    --name "doc-processor-deployment" `
    --location $LOCATION `
    --template-file main.bicep `
    --parameters environmentName=$ENV_NAME location=$LOCATION `
    --query "properties.outputs" -o json | ConvertFrom-Json

# Extract resource group and function app name from deployment outputs
$resourceGroupName = $deployment.resourceGroupName.value
$functionAppName = $deployment.functionAppName.value

Write-Host "Infrastructure deployment completed."
Write-Host "Resource Group: $resourceGroupName"
Write-Host "Function App Name: $functionAppName"

# Create temporary folders in the infrastructure directory
$publishFolder = Join-Path $PSScriptRoot "publish"
$zipPath = Join-Path $PSScriptRoot "function-app.zip"

# Build and publish the function app from the backend directory
Write-Host "Building and publishing function app..."
$backendProjectPath = Join-Path $rootDir "backend/backend.csproj"
dotnet publish $backendProjectPath -c Release -o $publishFolder

# Create ZIP file for deployment
Write-Host "Creating deployment package..."
if (Test-Path $zipPath) {
    Remove-Item $zipPath
}
Compress-Archive -Path "$publishFolder/*" -DestinationPath $zipPath -Force

# Deploy the function app code
Write-Host "Deploying function app code..."
az functionapp deployment source config-zip `
    -g $resourceGroupName `
    -n $functionAppName `
    --src $zipPath

# Clean up
Write-Host "Cleaning up temporary files..."
if (Test-Path $publishFolder) {
    Remove-Item -Path $publishFolder -Recurse -Force
}
if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}

Write-Host "Deployment completed successfully!"

# Get the function app URL for verification
$functionAppUrl = az functionapp show `
    -g $resourceGroupName `
    -n $functionAppName `
    --query "defaultHostName" `
    -o tsv

Write-Host "Function App URL: https://$functionAppUrl"