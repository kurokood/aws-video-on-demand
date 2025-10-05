# PowerShell script to install dependencies for all Lambda functions in the VOD architecture
# - Installs Node.js dependencies for each function with a package.json
# - Installs Python dependencies for mediainfo if requirements.txt is present

param(
    [switch]$Verbose,
    [switch]$Clean
)

Write-Host "Building Lambda Function Dependencies" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Function to clean node_modules if requested
function Remove-NodeModules {
    param([string]$FunctionPath)
    $nodeModulesPath = Join-Path $FunctionPath "node_modules"
    if (Test-Path $nodeModulesPath) {
        Write-Host "  🧹 Cleaning existing node_modules..." -ForegroundColor Yellow
        Remove-Item $nodeModulesPath -Recurse -Force
        Write-Host "  ✅ Cleaned node_modules" -ForegroundColor Green
    }
}

# Find all Lambda function directories with package.json
$lambdaRoot = Join-Path $PSScriptRoot "lambda_functions"
$nodeFunctions = Get-ChildItem -Path $lambdaRoot -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "package.json")
}

$totalFunctions = $nodeFunctions.Count
$successCount = 0
$errorCount = 0
$currentFunction = 0

foreach ($function in $nodeFunctions) {
    $currentFunction++
    $functionPath = $function.FullName
    $functionName = $function.Name
    Write-Host ""
    Write-Host "[$currentFunction/$totalFunctions] Processing $functionName" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    if ($Clean) {
        Remove-NodeModules -FunctionPath $functionPath
    }
    Write-Host "  🔧 Installing Node.js dependencies..." -ForegroundColor Yellow
    Push-Location $functionPath
    try {
        $npmArgs = @("install", "--production")
        if (-not $Verbose) { $npmArgs += "--silent" }
        & npm @npmArgs
        if ($LASTEXITCODE -eq 0) {
            if (Test-Path "node_modules") {
                $moduleCount = (Get-ChildItem "node_modules" -Directory).Count
                Write-Host "  ✅ Dependencies installed successfully ($moduleCount modules)" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "  ⚠️  No dependencies were installed (no node_modules created)" -ForegroundColor Yellow
                $successCount++
            }
        } else {
            Write-Error "  ❌ npm install failed with exit code $LASTEXITCODE"
            $errorCount++
        }
    } catch {
        Write-Error "  ❌ Error installing dependencies: $_"
        $errorCount++
    } finally {
        Pop-Location
    }
}

# Handle Python Lambda (mediainfo)
$mediainfoPath = Join-Path $lambdaRoot "mediainfo"
$requirementsPath = Join-Path $mediainfoPath "requirements.txt"
if (Test-Path $mediainfoPath) {
    Write-Host ""
    Write-Host "[mediainfo] Processing mediainfo (Python)" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    if (Test-Path $requirementsPath) {
        $pythonFound = $false
        try {
            python --version 2>$null
            if ($LASTEXITCODE -eq 0) { $pythonFound = $true }
        } catch { $pythonFound = $false }
        if ($pythonFound) {
            Write-Host "  🔧 Installing Python dependencies with pip..." -ForegroundColor Yellow
            Push-Location $mediainfoPath
            try {
                python -m pip install -r requirements.txt -t .
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✅ Python dependencies installed successfully" -ForegroundColor Green
                    $successCount++
                } else {
                    Write-Error "  ❌ Failed to install Python dependencies"
                    $errorCount++
                }
            } catch {
                Write-Error "  ❌ Error installing Python dependencies: $_"
                $errorCount++
            } finally {
                Pop-Location
            }
        } else {
            Write-Warning "  ⚠️  Python not found. Skipping dependency installation."
            Write-Host "  ✅ Function ready (assuming dependencies are built-in)" -ForegroundColor Green
            $successCount++
        }
    } else {
        Write-Host "  ✅ No requirements.txt found - using built-in dependencies only" -ForegroundColor Green
        $successCount++
    }
}

# Summary
Write-Host ""
Write-Host "=== Build Summary ===" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host "Total functions processed: $($nodeFunctions.Count + 1)" -ForegroundColor White
Write-Host "✅ Successful: $successCount" -ForegroundColor Green
Write-Host "❌ Errors: $errorCount" -ForegroundColor Red

if ($errorCount -eq 0) {
    Write-Host ""
    Write-Host "🎉 All Lambda function dependencies processed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Run 'terraform init' to initialize Terraform"
    Write-Host "  2. Run 'terraform plan' to review changes"
    Write-Host "  3. Run 'terraform apply' to deploy infrastructure"
    Write-Host "  OR use .\deploy.ps1 to run the full deployment pipeline"
    exit 0
} else {
    Write-Host ""
    Write-Host "⚠️  Some functions had issues. Please check the errors above." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Cyan
    Write-Host "  - Ensure Node.js and npm are installed and in your PATH"
    Write-Host "  - Try running with -Clean flag to remove existing node_modules"
    Write-Host "  - Use -Verbose flag for more detailed output"
    Write-Host "  - Check individual function package.json files for syntax errors"
    exit 1
}

Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Cyan
Write-Host "  .\install-lambda-dependencies.ps1           # Standard build"
Write-Host "  .\install-lambda-dependencies.ps1 -Clean   # Clean build"
Write-Host "  .\install-lambda-dependencies.ps1 -Verbose # Verbose output"
