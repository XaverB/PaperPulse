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

# Get the storage account details
Write-Host "Getting storage account details..."
$storageAccounts = az storage account list --resource-group $ResourceGroupName | ConvertFrom-Json
$storageAccount = $storageAccounts | Select-Object -First 1

if (-not $storageAccount) {
    Write-ErrorAndExit "No storage account found in resource group $ResourceGroupName"
}

# Get storage account key
$storageKeys = az storage account keys list --resource-group $ResourceGroupName --account-name $storageAccount.name | ConvertFrom-Json
$storageKey = $storageKeys[0].value

# Get Form Recognizer details
Write-Host "Getting Form Recognizer details..."
$formRecognizer = az cognitiveservices account list --resource-group $ResourceGroupName | ConvertFrom-Json |
    Where-Object { $_.kind -eq "FormRecognizer" } | Select-Object -First 1

if (-not $formRecognizer) {
    Write-ErrorAndExit "Form Recognizer service not found in resource group $ResourceGroupName"
}

$formRecognizerKeys = az cognitiveservices account keys list --resource-group $ResourceGroupName --name $formRecognizer.name | ConvertFrom-Json
$formRecognizerKey = $formRecognizerKeys.key1

# Update function app settings
Write-Host "Updating function app settings..."
$storageConnectionString = "DefaultEndpointsProtocol=https;AccountName=$($storageAccount.name);AccountKey=$storageKey;EndpointSuffix=core.windows.net"

Write-Host "Configuring app settings..."
$settings = @(
    "AzureWebJobsStorage=$storageConnectionString"
    "FUNCTIONS_WORKER_RUNTIME=dotnet-isolated"
    "FUNCTIONS_EXTENSION_VERSION=~4"
    "WEBSITE_RUN_FROM_PACKAGE=1"
    "FormRecognizerEndpoint=$($formRecognizer.properties.endpoint)"
    "FormRecognizerKey=$formRecognizerKey"
    "WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED=1"
    "DOTNET_VERSION=8.0"
)

az functionapp config appsettings set `
    --resource-group $ResourceGroupName `
    --name $FunctionAppName `
    --settings $settings

# Build project
Write-Host "Building project..."
$projectPath = "./backend/backend.csproj"
if (-not (Test-Path $projectPath)) {
    Write-ErrorAndExit "Project file not found at $projectPath"
}

# Clean previous builds
Write-Host "Cleaning previous builds..."
dotnet clean $projectPath -c Release
if (-not $?) { Write-ErrorAndExit "Failed to clean project" }

# Create publish folder
$publishFolder = Join-Path $PSScriptRoot "publish"
if (Test-Path $publishFolder) {
    Remove-Item -Path $publishFolder -Recurse -Force
}

# Build and publish
Write-Host "Publishing project..."
dotnet publish $projectPath `
    --configuration Release `
    --output $publishFolder `
    --runtime linux-x64 `
    --self-contained true `
    /p:PublishReadyToRun=true

if (-not $?) {
    Write-ErrorAndExit "Failed to publish project"
}

# Create deployment package
Write-Host "Creating deployment package..."
$zipPath = Join-Path $PSScriptRoot "function-app.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Ensure .azurefunctions is included in the archive
Write-Host "Creating deployment package with Azure Functions files..."
Push-Location $publishFolder
try {
    # Create a list of all items to include
    $items = @(
        ".**"  # Include all hidden directories
        "*"    # Include all regular files and directories
    )
    
    # Create the archive with all items
    Compress-Archive -Path $items -DestinationPath $zipPath -Force
}
finally {
    Pop-Location
}

# Stop the function app
Write-Host "Stopping function app..."
az functionapp stop --resource-group $ResourceGroupName --name $FunctionAppName

# Deploy using REST API
Write-Host "Deploying function app..."
$publishingCredentials = az webapp deployment list-publishing-credentials `
    --resource-group $ResourceGroupName `
    --name $FunctionAppName | ConvertFrom-Json

$username = $publishingCredentials.publishingUserName
$password = $publishingCredentials.publishingPassword
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))
$apiUrl = "https://$FunctionAppName.scm.azurewebsites.net/api/zipdeploy"

try {
    Write-Host "Uploading package..."
    $result = Invoke-RestMethod -Uri $apiUrl `
        -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} `
        -Method POST `
        -InFile $zipPath `
        -ContentType "application/zip"
    
    Write-Host "Package uploaded successfully"
}
catch {
    Write-Host "Error during deployment: $_" -ForegroundColor Red
    Write-Host "Response: $($_.Exception.Response.StatusCode.Value__) - $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
    Write-ErrorAndExit "Deployment failed"
}

# Start the function app
Write-Host "Starting function app..."
az functionapp start --resource-group $ResourceGroupName --name $FunctionAppName

# Wait for the app to start
Write-Host "Waiting for app to start..."
Start-Sleep -Seconds 30

# Restart to ensure changes are picked up
Write-Host "Restarting function app..."
az functionapp restart --resource-group $ResourceGroupName --name $FunctionAppName

# Wait for restart
Write-Host "Waiting for restart to complete..."
Start-Sleep -Seconds 30

# Show URLs and next steps
Write-Host "`nDeployment completed!"
Write-Host "Function App URL: https://$FunctionAppName.azurewebsites.net"
Write-Host "Kudu URL: https://$FunctionAppName.scm.azurewebsites.net"

# Show current app settings
Write-Host "`nVerifying app settings..."
$currentSettings = az functionapp config appsettings list `
    --resource-group $ResourceGroupName `
    --name $FunctionAppName | ConvertFrom-Json

Write-Host "Current app settings:"
$currentSettings | ForEach-Object {
    if ($_.name -like "*Key*" -or $_.name -like "*Connection*") {
        Write-Host "$($_.name): [Hidden]"
    } else {
        Write-Host "$($_.name): $($_.value)"
    }
}

Write-Host "`nNext steps:"
Write-Host "1. Check the function app in Azure Portal"
Write-Host "2. View logs at: https://$FunctionAppName.scm.azurewebsites.net/api/logstream"
Write-Host "3. If functions are not visible, try:"
Write-Host "   - Checking the Application Settings in Azure Portal"
Write-Host "   - Reviewing the log stream for any startup errors"
Write-Host "   - Verifying the Form Recognizer connection"

# Cleanup
Write-Host "`nCleaning up temporary files..."
Remove-Item -Path $publishFolder -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue