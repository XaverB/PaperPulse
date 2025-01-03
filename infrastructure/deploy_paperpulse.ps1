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

# Call the deploy_functions.ps1 script from root directory
#$deployFunctionsPath = Join-Path $rootDir "deploy_functions.ps1"
#Write-Host "Deploying function app code using $deployFunctionsPath..."

#& $deployFunctionsPath -ResourceGroupName $resourceGroupName -FunctionAppName $functionAppName

Write-Host "Deployment completed successfully!"

# Get the function app URL for verification
#$functionAppUrl = az functionapp show `
#    -g $resourceGroupName `
#    -n $functionAppName `
#    --query "defaultHostName" `
#    -o tsv

#Write-Host "Function App URL: https://$functionAppUrl"