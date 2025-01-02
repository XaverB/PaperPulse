param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    [Parameter(Mandatory=$false)]
    [string]$FunctionUrl = "http://localhost:7071/api/documents/upload",
    [Parameter(Mandatory=$false)]
    [string]$FunctionKey = ""
)

if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

$curlArgs = @(
    '-X', 'POST',
    '-H', 'Content-Type: multipart/form-data',
    '-F', "file=@`"$FilePath`""
)

if ($FunctionKey) {
    $curlArgs += @('-H', "x-functions-key: $FunctionKey")
}

$curlArgs += $FunctionUrl

$response = & curl.exe @curlArgs
if ($LASTEXITCODE -eq 0) {
    Write-Host "Upload successful!"
    $response
} else {
    Write-Error "Upload failed with exit code $LASTEXITCODE"
    Write-Error $response
}