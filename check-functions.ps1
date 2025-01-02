param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$FunctionAppName
)

Write-Host "Checking function app configuration..." -ForegroundColor Cyan

# Get function app settings
Write-Host "`nChecking app settings..." -ForegroundColor Yellow
$settings = az functionapp config appsettings list `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName | ConvertFrom-Json

Write-Host "Runtime version:" -ForegroundColor Green
$settings | Where-Object { $_.name -eq 'FUNCTIONS_EXTENSION_VERSION' } | ForEach-Object { Write-Host $_.value }

Write-Host "Runtime:" -ForegroundColor Green
$settings | Where-Object { $_.name -eq 'FUNCTIONS_WORKER_RUNTIME' } | ForEach-Object { Write-Host $_.value }

# List functions
Write-Host "`nListing deployed functions..." -ForegroundColor Yellow
az functionapp function list `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName

# Get function app master key
Write-Host "`nGetting function app master key..." -ForegroundColor Yellow
az functionapp keys list `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName

# Check deployment status
Write-Host "`nChecking recent deployments..." -ForegroundColor Yellow
az webapp deployment list `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName

# Show the Kudu site for troubleshooting
$kuduUrl = "https://$FunctionAppName.scm.azurewebsites.net"
Write-Host "`nKudu diagnostics site: $kuduUrl" -ForegroundColor Cyan