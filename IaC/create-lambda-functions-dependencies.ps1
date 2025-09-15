# Build script for Lambda functions
Write-Host "Building Lambda functions..."

# Node.js Lambda functions
$lambdaFunctions = @(
    "step-functions",
    "input-validate", 
    "encode",
    "profiler",
    "dynamo-update",
    "error-handler",
    "output-validate",
    "archive-source",
    "sns-notification",
    "sqs-publish",
    "media-package-assets"
)

foreach ($function in $lambdaFunctions) {
    $functionPath = "lambda_functions/$function"
    
    if (Test-Path $functionPath) {
        Write-Host "Building $function..."
        
        # Install npm dependencies
        if (Test-Path "$functionPath/package.json") {
            Write-Host "  Installing Node.js dependencies..."
            Push-Location $functionPath
            npm install --production
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Dependencies installed successfully"
            } else {
                Write-Error "  Failed to install dependencies"
            }
            Pop-Location
        } else {
            Write-Host "  No package.json found, skipping dependency installation"
        }
    } else {
        Write-Warning "Function directory not found: $functionPath"
    }
}

# Handle Python function (mediainfo)
$pythonFunction = "lambda_functions/mediainfo"
if (Test-Path $pythonFunction) {
    Write-Host "Building mediainfo (Python)..."
    # Python dependencies would be installed here if needed
    # pip install -r requirements.txt -t .
}

Write-Host "Lambda function build complete!"

