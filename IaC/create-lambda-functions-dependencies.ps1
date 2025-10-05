# Build script for Lambda functions
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

$totalFunctions = $lambdaFunctions.Count + 1  # +1 for Python mediainfo function
$successCount = 0
$errorCount = 0
$currentFunction = 0

# Process Node.js Lambda functions
foreach ($function in $lambdaFunctions) {
    $currentFunction++
    $functionPath = "lambda_functions/$function"
    
    Write-Host ""
    Write-Host "[$currentFunction/$totalFunctions] Processing $function" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    
    if (Test-Path $functionPath) {
        # Install npm dependencies
        if (Test-Path "$functionPath/package.json") {
            Write-Host "  📦 Found package.json" -ForegroundColor Green
            # Clean if requested
            if ($Clean) {
                Remove-NodeModules -FunctionPath $functionPath
            }
            Write-Host "  🔧 Installing Node.js dependencies..." -ForegroundColor Yellow
            Push-Location $functionPath
            try {
                $npmArgs = @("install", "--production")
                if (-not $Verbose) {
                    $npmArgs += "--silent"
                }
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
        } else {
            Write-Warning "  ⚠️  No package.json found in $functionPath"
            $errorCount++
        }
    } else {
        Write-Warning "  ❌ Function directory not found: $functionPath"
    $errorCount++
}

# End foreach ($function in $lambdaFunctions)


# Handle Python function (mediainfo)
$currentFunction++
$pythonFunction = "lambda_functions/mediainfo"

Write-Host ""
Write-Host "[$currentFunction/$totalFunctions] Processing mediainfo (Python)" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

if (Test-Path $pythonFunction) {
    Write-Host "  🐍 Found Python Lambda function" -ForegroundColor Green
    $requirementsPath = Join-Path $pythonFunction "requirements.txt"
    if (Test-Path $requirementsPath) {
        Write-Host "  📋 Found requirements.txt" -ForegroundColor Green
        $pythonFound = $false
        try {
            python --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                $pythonFound = $true
            }
        } catch {
            $pythonFound = $false
        }
        if ($pythonFound) {
            Write-Host "  🔧 Installing Python dependencies with pip..." -ForegroundColor Yellow
            Push-Location $pythonFunction
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

    } # End if (Test-Path $pythonFunction)

Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Cyan
Write-Host "  .\create-lambda-functions-dependencies.ps1           # Standard build"
Write-Host "  .\create-lambda-functions-dependencies.ps1 -Clean   # Clean build"
Write-Host "  .\create-lambda-functions-dependencies.ps1 -Verbose # Verbose output"

