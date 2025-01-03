param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    [Parameter(Mandatory=$false)]
    [string]$FunctionUrl = "http://localhost:7071/api/documents/upload",
    [Parameter(Mandatory=$false)]
    [string]$FunctionKey = ""
)

# Validate file exists
if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

# Get file name and escape it properly
$fileName = [System.Web.HttpUtility]::UrlEncode((Split-Path $FilePath -Leaf))

# Build curl command with proper headers and escaping
$curlArgs = @(
    '--ssl-no-revoke',  # Add this for HTTPS support
    '-X', 'POST',
    '-H', 'Content-Type: application/octet-stream',
    '-H', "Content-Disposition: attachment; filename=`"$fileName`"",
    '-H', "X-File-Name: $fileName",
    '--data-binary', "@`"$FilePath`"" # Properly quote the file path
)

# Add function key if provided
if ($FunctionKey) {
    $curlArgs += @('-H', "x-functions-key: $FunctionKey")
}

# Add URL (must be the last argument)
$curlArgs += "`"$FunctionUrl`""

Write-Host "Uploading file: $fileName"

try {
    # Execute curl with all arguments properly escaped
    $response = & curl.exe @curlArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Upload successful!"
        try {
            # Try to parse and display JSON response nicely
            $jsonResponse = $response | ConvertFrom-Json
            Write-Host "Blob Name: $($jsonResponse.blobName)"
            Write-Host "Original File Name: $($jsonResponse.originalFileName)"
        }
        catch {
            # If not JSON, just show raw response
            Write-Host "Response: $response"
        }
    }
    else {
        Write-Error "Upload failed with exit code $LASTEXITCODE"
        Write-Error $response
        exit 1
    }
}
catch {
    Write-Error "Error executing curl command: $_"
    exit 1
}