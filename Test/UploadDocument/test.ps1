This is a test document
for PaperPulse processing# Upload-ToPaperPulse.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath)]
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName)]  # Change this to match your resource group
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName)]  # Change this to match your environment
)

# Ensure we're logged into Azure
$context = Get-AzContext
if (-not $context) {
    Write-Host "Not logged into Azure. Attempting to log in..."
    Connect-AzAccount
}

# Get the function app name from the resource group
$functionApp = Get-AzFunctionApp -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "func-$EnvironmentName-*" }
if (-not $functionApp) {
    throw "Could not find function app in resource group $ResourceGroupName"
}

# Get the function key
$functionKeys = Invoke-AzRestMethod -Uri "https://management.azure.com$($functionApp.Id)/host/default/listKeys?api-version=2022-03-01" -Method POST
$functionKey = ($functionKeys.Content | ConvertFrom-Json).functionKeys.default

# Verify file exists
if (-not (Test-Path $FilePath)) {
    throw "File not found: $FilePath"
}

# Create HTTP client and multipart content
$client = New-Object System.Net.Http.HttpClient
$multipartContent = New-Object System.Net.Http.MultipartFormDataContent

# Read file content and add to multipart content
$fileStream = [System.IO.File]::OpenRead($FilePath)
$fileContent = New-Object System.Net.Http.StreamContent($fileStream)
$fileName = [System.IO.Path]::GetFileName($FilePath)
$multipartContent.Add($fileContent, "file", $fileName)

# Set up the request
$functionUrl = "https://$($functionApp.DefaultHostName)/api/documents/upload"
$client.DefaultRequestHeaders.Add("x-functions-key", $functionKey)

Write-Host "Uploading $fileName to $functionUrl"

try {
    # Send the request
    $response = $client.PostAsync($functionUrl, $multipartContent).Result
    
    # Get and display the response
    $result = $response.Content.ReadAsStringAsync().Result
    
    if ($response.IsSuccessStatusCode) {
        Write-Host "Upload successful!"
        Write-Host "Response: $result"
    } else {
        Write-Host "Upload failed with status code: $($response.StatusCode)"
        Write-Host "Error: $result"
    }
}
catch {
    Write-Host "Error occurred during upload: $_"
}
finally {
    # Clean up
    $fileStream.Dispose()
    $fileContent.Dispose()
    $multipartContent.Dispose()
    $client.Dispose()
}