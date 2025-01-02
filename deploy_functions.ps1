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

# Configure TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Function to retry operations
function Invoke-CommandWithRetry {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 10
    )
    
    $attempt = 1
    do {
        try {
            Write-Host "Attempt $attempt of $MaxAttempts..."
            & $ScriptBlock
            return $true
        }
        catch {
            Write-Host "Attempt $attempt failed: $_"
            if ($attempt -lt $MaxAttempts) {
                Write-Host "Waiting $DelaySeconds seconds before retrying..."
                Start-Sleep -Seconds $DelaySeconds
            }
            $attempt++
        }
    } while ($attempt -le $MaxAttempts)
    
    return $false
}

# Verify Azure CLI is logged in
$loginStatus = az account show 2>$null
if (-not $?) {
    Write-Host "Not logged in to Azure. Initiating login..."
    az login
    if (-not $?) { Write-ErrorAndExit "Failed to login to Azure" }
}

# Build and prepare the package
try {
    # Project paths
    $projectPath = "./backend/backend.csproj"
    $publishFolder = Join-Path $PSScriptRoot "publish"
    $zipPath = Join-Path $PSScriptRoot "function-app.zip"

    # Clean and create publish folder
    if (Test-Path $publishFolder) {
        Remove-Item -Path $publishFolder -Recurse -Force
    }
    New-Item -ItemType Directory -Path $publishFolder -Force | Out-Null

    # Build and publish with detailed output
    Write-Host "Building and publishing project..."
    $publishResult = dotnet publish $projectPath `
        --configuration Release `
        --output $publishFolder `
        --runtime linux-x64 `
        --self-contained true `
        /p:PublishReadyToRun=true `
        /consoleloggerparameters:ErrorsOnly

    if (-not $?) {
        Write-ErrorAndExit "Failed to publish project: $publishResult"
    }

    # Create deployment package with progress
    Write-Host "Creating deployment package..."
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    Push-Location $publishFolder
    try {
        $compressionResult = Compress-Archive -Path @(".**", "*") -DestinationPath $zipPath -Force
        if (-not (Test-Path $zipPath)) {
            Write-ErrorAndExit "Failed to create zip file"
        }
    }
    finally {
        Pop-Location
    }

    # Get publishing credentials
    Write-Host "Getting publishing credentials..."
    $publishingCredentials = az webapp deployment list-publishing-credentials `
        --resource-group $ResourceGroupName `
        --name $FunctionAppName | ConvertFrom-Json

    $username = $publishingCredentials.publishingUserName
    $password = $publishingCredentials.publishingPassword
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))
    $apiUrl = "https://$FunctionAppName.scm.azurewebsites.net/api/zipdeploy"

    # Stop the function app
    Write-Host "Stopping function app..."
    az functionapp stop --resource-group $ResourceGroupName --name $FunctionAppName

    # Deploy with retry logic
    Write-Host "Deploying package..."
    $deploymentSuccess = Invoke-CommandWithRetry -ScriptBlock {
        $response = Invoke-RestMethod -Uri $apiUrl `
            -Headers @{
                Authorization=("Basic {0}" -f $base64AuthInfo)
                "If-Match"="*"
            } `
            -Method POST `
            -InFile $zipPath `
            -ContentType "application/zip" `
            -TimeoutSec 600

        Write-Host "Deployment response: $response"
    }

    if (-not $deploymentSuccess) {
        Write-ErrorAndExit "Failed to deploy after multiple attempts"
    }

    # Start and restart the function app
    Write-Host "Starting function app..."
    az functionapp start --resource-group $ResourceGroupName --name $FunctionAppName

    Write-Host "Waiting for app to start..."
    Start-Sleep -Seconds 30

    Write-Host "Restarting function app..."
    az functionapp restart --resource-group $ResourceGroupName --name $FunctionAppName

    Write-Host "Deployment completed successfully!"
}
catch {
    Write-Host "Detailed error information:" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-ErrorAndExit "Deployment failed with error: $_"
}
finally {
    # Cleanup
    Write-Host "Cleaning up temporary files..."
    Remove-Item -Path $publishFolder -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
}