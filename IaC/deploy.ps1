# Deploy script for VOD Infrastructure
# This script will first install Lambda function dependencies, then deploy the infrastructure

param(
    [switch]$SkipDependencies,
    [switch]$SkipPlan,
    [string]$TerraformAction = "apply",
    [switch]$Help
)

# Display help information
if ($Help) {
    Write-Host "VOD Infrastructure Deployment Script" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: .\deploy.ps1 [OPTIONS]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -SkipDependencies       Skip Lambda function dependency installation"
    Write-Host "  -SkipPlan              Skip Terraform plan step (deploy directly)"
    Write-Host "  -TerraformAction       Specify 'apply' or 'destroy' (default: apply)"
    Write-Host "  -Help                  Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\deploy.ps1                           # Full deployment with plan"
    Write-Host "  .\deploy.ps1 -SkipPlan                 # Deploy without plan (faster)"
    Write-Host "  .\deploy.ps1 -SkipDependencies        # Skip Lambda dependencies"
    Write-Host "  .\deploy.ps1 -TerraformAction destroy  # Destroy infrastructure"
    exit 0
}

Write-Host "Starting VOD Infrastructure Deployment" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host ""
    Write-Host "Checking Prerequisites" -ForegroundColor Yellow
    Write-Host "======================" -ForegroundColor Yellow
    
    $errors = 0
    
    # Check if we're in the correct directory
    if (-not (Test-Path "main.tf")) {
        Write-Error "Error: main.tf not found. Please run this script from the IaC directory."
        $errors++
    }
    
    # Check if Terraform is installed
    try {
        $terraformVersion = terraform --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Terraform is installed: $($terraformVersion.Split("`n")[0])" -ForegroundColor Green
        } else {
            Write-Error "❌ Terraform is not installed or not in PATH"
            $errors++
        }
    } catch {
        Write-Error "❌ Terraform is not installed or not in PATH"
        $errors++
    }
    
    # Check AWS CLI
    try {
        $awsVersion = aws --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ AWS CLI is installed: $awsVersion" -ForegroundColor Green
        } else {
            Write-Warning "⚠️ AWS CLI not found - may be required for some operations"
        }
    } catch {
        Write-Warning "⚠️ AWS CLI not found - may be required for some operations"
    }
    
    # Check Node.js for Lambda dependencies
    if (-not $SkipDependencies) {
        try {
            $nodeVersion = node --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Node.js is installed: $nodeVersion" -ForegroundColor Green
            } else {
                Write-Error "❌ Node.js is required for Lambda dependencies"
                $errors++
            }
        } catch {
            Write-Error "❌ Node.js is required for Lambda dependencies"
            $errors++
        }
        
        try {
            $npmVersion = npm --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ npm is installed: $npmVersion" -ForegroundColor Green
            } else {
                Write-Error "❌ npm is required for Lambda dependencies"
                $errors++
            }
        } catch {
            Write-Error "❌ npm is required for Lambda dependencies"
            $errors++
        }
    }
    
    # Check AWS credentials
    try {
        $awsIdentity = aws sts get-caller-identity 2>$null
        if ($LASTEXITCODE -eq 0) {
            $identity = $awsIdentity | ConvertFrom-Json
            Write-Host "✅ AWS credentials configured for Account: $($identity.Account)" -ForegroundColor Green
        } else {
            Write-Warning "⚠️ AWS credentials not configured or not accessible"
        }
    } catch {
        Write-Warning "⚠️ Could not verify AWS credentials"
    }
    
    if ($errors -gt 0) {
        Write-Error "Prerequisites check failed. Please resolve the above issues before continuing."
        exit 1
    }
    
    Write-Host "✅ All prerequisites satisfied" -ForegroundColor Green
}

# Run prerequisites check
Test-Prerequisites

# Step 1: Install Lambda function dependencies (unless skipped)
if (-not $SkipDependencies) {
    Write-Host ""
    Write-Host "Step 1: Installing Lambda Function Dependencies" -ForegroundColor Yellow
    Write-Host "=================================================" -ForegroundColor Yellow
    
    if (Test-Path "create-lambda-functions-dependencies.ps1") {
        try {
            & ".\create-lambda-functions-dependencies.ps1"
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Lambda dependencies installation failed. Exiting deployment."
                exit 1
            }
            Write-Host "Lambda dependencies installed successfully" -ForegroundColor Green
        } catch {
            Write-Error "Error running Lambda dependencies script: $_"
            exit 1
        }
    } else {
        Write-Warning "create-lambda-functions-dependencies.ps1 not found. Skipping dependency installation."
    }
} else {
    Write-Host "Skipping Lambda dependencies installation (-SkipDependencies flag used)" -ForegroundColor Yellow
}

# Step 2: Initialize Terraform
Write-Host ""
Write-Host "Step 2: Initializing Terraform" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Yellow

try {
    terraform init
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform initialization failed. Exiting deployment."
        exit 1
    }
    Write-Host "Terraform initialized successfully" -ForegroundColor Green
} catch {
    Write-Error "Error during Terraform initialization: $_"
    exit 1
}

# Step 3: Terraform validation
Write-Host ""
Write-Host "Step 3: Validating Terraform Configuration" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow

try {
    terraform validate
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform validation failed. Exiting deployment."
        exit 1
    }
    Write-Host "Terraform configuration is valid" -ForegroundColor Green
} catch {
    Write-Error "Error during Terraform validation: $_"
    exit 1
}

# Step 4: Terraform plan (unless skipped)
if (-not $SkipPlan) {
    Write-Host ""
    Write-Host "Step 4: Creating Terraform Plan" -ForegroundColor Yellow
    Write-Host "=================================" -ForegroundColor Yellow
    
    try {
        terraform plan -out=tfplan
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform plan failed. Exiting deployment."
            exit 1
        }
        Write-Host "Terraform plan created successfully" -ForegroundColor Green
    } catch {
        Write-Error "Error during Terraform plan: $_"
        exit 1
    }
} else {
    Write-Host "Skipping Terraform plan (-SkipPlan flag used)" -ForegroundColor Yellow
}

# Step 5: Terraform apply
Write-Host ""
Write-Host "Step 5: Applying Terraform Configuration" -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Yellow

try {
    if ($TerraformAction -eq "apply") {
        if (Test-Path "tfplan") {
            terraform apply tfplan
        } else {
            terraform apply -auto-approve
        }
    } elseif ($TerraformAction -eq "destroy") {
        Write-Host "WARNING: You are about to DESTROY the infrastructure!" -ForegroundColor Red
        $confirmation = Read-Host "Type 'yes' to confirm destruction"
        if ($confirmation -eq "yes") {
            terraform destroy -auto-approve
        } else {
            Write-Host "Destruction cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    } else {
        Write-Error "Invalid Terraform action: $TerraformAction. Use 'apply' or 'destroy'."
        exit 1
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform $TerraformAction failed."
        exit 1
    }
    Write-Host "Terraform $TerraformAction completed successfully" -ForegroundColor Green
} catch {
    Write-Error "Error during Terraform $TerraformAction : $_"
    exit 1
}

# Cleanup
if (Test-Path "tfplan") {
    Remove-Item "tfplan" -Force
    Write-Host "Cleaned up temporary plan file" -ForegroundColor Gray
}

# Final summary
Write-Host ""
Write-Host "Deployment Summary" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green
Write-Host "Lambda dependencies: Installed" -ForegroundColor Green
Write-Host "Terraform initialization: Completed" -ForegroundColor Green
Write-Host "Terraform validation: Passed" -ForegroundColor Green
if (-not $SkipPlan) {
    Write-Host "Terraform plan: Created" -ForegroundColor Green
}
Write-Host "Terraform $TerraformAction : Completed" -ForegroundColor Green
Write-Host ""
Write-Host "Infrastructure deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Cyan
Write-Host "  .\deploy.ps1                    # Full deployment with plan"
Write-Host "  .\deploy.ps1 -SkipPlan          # Deploy without plan (faster)"
Write-Host "  .\deploy.ps1 -SkipDependencies # Skip Lambda dependencies"
Write-Host "  .\deploy.ps1 -TerraformAction destroy # Destroy infrastructure"
