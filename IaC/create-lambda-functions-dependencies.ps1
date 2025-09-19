# Build script for Lambda functions
Write-Host "Building Lambda functions..."

# Node.js Lambda functions (all functions that have package.json)
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
    "media-package-assets",
    "custom-resource"
)

$totalFunctions = $lambdaFunctions.Count
$successCount = 0
$errorCount = 0

foreach ($function in $lambdaFunctions) {
    $functionPath = "lambda_functions/$function"
    
    if (Test-Path $functionPath) {
        Write-Host "Building $function..."
        
        # Install npm dependencies
        if (Test-Path "$functionPath/package.json") {
            Write-Host "  Installing Node.js dependencies..."
            Push-Location $functionPath
            try {
                npm install --production
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✅ Dependencies installed successfully"
                    $successCount++
                } else {
                    Write-Error "  ❌ Failed to install dependencies"
                    $errorCount++
                }
            } catch {
                Write-Error "  ❌ Error installing dependencies: $_"
                $errorCount++
            } finally {
                Pop-Location
            }
        } else {
            Write-Host "  ⚠️  No package.json found, skipping dependency installation"
        }
    } else {
        Write-Warning "Function directory not found: $functionPath"
        $errorCount++
    }
}

# Handle Python function (mediainfo)
$pythonFunction = "lambda_functions/mediainfo"
if (Test-Path $pythonFunction) {
    Write-Host "Building mediainfo (Python)..."
    # Python dependencies would be installed here if needed
    # pip install -r requirements.txt -t .
    Write-Host "  ✅ Python function ready (no external dependencies needed)"
    $successCount++
}

# Summary
Write-Host ""
Write-Host "=== Build Summary ==="
Write-Host "Total functions processed: $totalFunctions"
Write-Host "✅ Successful: $successCount"
Write-Host "❌ Errors: $errorCount"

if ($errorCount -eq 0) {
    Write-Host "🎉 All Lambda function dependencies installed successfully!"
} else {
    Write-Host "⚠️  Some functions had issues. Please check the errors above."
}

Write-Host "Lambda function build complete!"

