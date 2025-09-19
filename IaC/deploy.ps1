# Deploy script for VOD Infrastructure
# This script will first install Lambda function dependencies, then deploy the infrastructure

param(
    [switch]$SkipDependencies,
    [switch]$SkipPlan,
    [string]$TerraformAction = "apply"
)

Write-Host "Starting VOD Infrastructure Deployment" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

# Check if we're in the correct directory
if (-not (Test-Path "main.tf")) {
    Write-Error "Error: main.tf not found. Please run this script from the IaC directory."
    exit 1
}

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

# Step 2: Terraform validation
Write-Host ""
Write-Host "Step 2: Validating Terraform Configuration" -ForegroundColor Yellow
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

# Step 3: Terraform plan (unless skipped)
if (-not $SkipPlan) {
    Write-Host ""
    Write-Host "Step 3: Creating Terraform Plan" -ForegroundColor Yellow
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

# Step 4: Terraform apply
Write-Host ""
Write-Host "Step 4: Applying Terraform Configuration" -ForegroundColor Yellow
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
