#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Video on Demand Custom Resources Infrastructure

.DESCRIPTION
    This script deploys the Video on Demand custom resources infrastructure using Terraform.
    It handles dependency installation, Lambda packaging, and Terraform deployment.

.PARAMETER StackName
    Name of the VOD stack for resource naming

.PARAMETER AdminEmail
    Email address for SNS notifications

.PARAMETER Region
    AWS region for deployment

.PARAMETER EnableMediaPackage
    Enable MediaPackage VOD in the workflow (Yes/No)

.PARAMETER FrameCapture
    Enable frame capture in MediaConvert jobs (Yes/No)

.PARAMETER Glacier
    Archive source assets setting (DISABLED/GLACIER/DEEP_ARCHIVE)

.PARAMETER AcceleratedTranscoding
    Enable accelerated transcoding (ENABLED/DISABLED/PREFERRED)

.PARAMETER WorkflowTrigger
    How the workflow will be triggered (VideoFile/MetadataFile)

.PARAMETER Action
    Action to perform: plan, apply, or destroy

.EXAMPLE
    .\deploy-custom-resources.ps1 -StackName "my-vod" -AdminEmail "admin@example.com" -Region "us-east-1"

.EXAMPLE
    .\deploy-custom-resources.ps1 -StackName "my-vod" -AdminEmail "admin@example.com" -Region "us-east-1" -EnableMediaPackage "Yes" -Action "plan"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [Parameter(Mandatory = $true)]
    [string]$AdminEmail,

    [Parameter(Mandatory = $true)]
    [string]$Region,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Yes", "No")]
    [string]$EnableMediaPackage = "No",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Yes", "No")]
    [string]$FrameCapture = "No",

    [Parameter(Mandatory = $false)]
    [ValidateSet("DISABLED", "GLACIER", "DEEP_ARCHIVE")]
    [string]$Glacier = "DISABLED",

    [Parameter(Mandatory = $false)]
    [ValidateSet("ENABLED", "DISABLED", "PREFERRED")]
    [string]$AcceleratedTranscoding = "PREFERRED",

    [Parameter(Mandatory = $false)]
    [ValidateSet("VideoFile", "MetadataFile")]
    [string]$WorkflowTrigger = "VideoFile",

    [Parameter(Mandatory = $false)]
    [ValidateSet("plan", "apply", "destroy")]
    [string]$Action = "apply",

    [Parameter(Mandatory = $false)]
    [switch]$EnableSns,

    [Parameter(Mandatory = $false)]
    [switch]$EnableSqs
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$IaCDir = $ScriptDir

Write-Host "=== Video on Demand Custom Resources Deployment ===" -ForegroundColor Green
Write-Host "Stack Name: $StackName" -ForegroundColor Cyan
Write-Host "Admin Email: $AdminEmail" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Enable MediaPackage: $EnableMediaPackage" -ForegroundColor Cyan
Write-Host "Frame Capture: $FrameCapture" -ForegroundColor Cyan
Write-Host "Glacier: $Glacier" -ForegroundColor Cyan
Write-Host "Accelerated Transcoding: $AcceleratedTranscoding" -ForegroundColor Cyan
Write-Host "Workflow Trigger: $WorkflowTrigger" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Cyan
Write-Host ""

# Validate email format
if ($AdminEmail -notmatch '^[_A-Za-z0-9-\+]+(\.[_A-Za-z0-9-]+)*@[A-Za-z0-9-]+(\.[A-Za-z0-9]+)*(\.[A-Za-z]{2,})$') {
    Write-Error "Invalid email format: $AdminEmail"
    exit 1
}

# Check if AWS CLI is installed
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error "AWS CLI is not installed or not in PATH"
    exit 1
}

# Check if Terraform is installed
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Error "Terraform is not installed or not in PATH"
    exit 1
}

# Check if Node.js is installed for Lambda function dependencies
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js is not installed or not in PATH. Required for Lambda function dependencies."
    exit 1
}

# Check if npm is installed
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Error "npm is not installed or not in PATH. Required for Lambda function dependencies."
    exit 1
}

# Verify AWS credentials
try {
    $identity = aws sts get-caller-identity | ConvertFrom-Json
    Write-Host "AWS Account: $($identity.Account)" -ForegroundColor Yellow
    Write-Host "AWS User: $($identity.Arn)" -ForegroundColor Yellow
} catch {
    Write-Error "Failed to get AWS caller identity. Please check your AWS credentials."
    exit 1
}

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Function to install Lambda dependencies
function Install-LambdaDependencies {
    Write-Host "Installing Lambda function dependencies..." -ForegroundColor Yellow
    
    # Custom Resource Lambda
    $customResourceDir = Join-Path $IaCDir "lambda_functions/custom-resource"
    if (Test-Path $customResourceDir) {
        Write-Host "Installing dependencies for custom-resource Lambda..." -ForegroundColor Cyan
        Push-Location $customResourceDir
        try {
            npm install --production --no-audit --no-fund
            Write-Host "Dependencies installed successfully" -ForegroundColor Green
        } catch {
            Write-Error "Failed to install dependencies for custom-resource Lambda: $_"
            exit 1
        } finally {
            Pop-Location
        }
    }
    
    # Install dependencies for other Lambda functions if they exist
    $lambdaFunctionsDir = Join-Path $IaCDir "lambda_functions"
    $lambdaDirs = Get-ChildItem -Path $lambdaFunctionsDir -Directory | Where-Object { $_.Name -ne "custom-resource" }
    
    foreach ($dir in $lambdaDirs) {
        $packageJsonPath = Join-Path $dir.FullName "package.json"
        if (Test-Path $packageJsonPath) {
            Write-Host "Installing dependencies for $($dir.Name) Lambda..." -ForegroundColor Cyan
            Push-Location $dir.FullName
            try {
                npm install --production --no-audit --no-fund
                Write-Host "Dependencies installed successfully" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to install dependencies for $($dir.Name) Lambda: $_"
            } finally {
                Pop-Location
            }
        }
    }
}

# Function to create terraform.tfvars file
function New-TerraformVars {
    Write-Host "Creating terraform.tfvars file..." -ForegroundColor Yellow
    
    $tfvarsPath = Join-Path $IaCDir "terraform.tfvars"
    # Set default values for switch parameters if not specified
    $enableSnsValue = if ($EnableSns) { "Yes" } else { "No" }
    $enableSqsValue = if ($EnableSqs) { "Yes" } else { "No" }

    $tfvarsContent = @"
# Video on Demand Custom Resources Configuration
stack_name              = "$StackName"
admin_email             = "$AdminEmail"
aws_region              = "$Region"
workflow_trigger        = "$WorkflowTrigger"
glacier                 = "$Glacier"
frame_capture          = "$FrameCapture"
enable_media_package   = "$EnableMediaPackage"
enable_sns             = "$enableSnsValue"
enable_sqs             = "$enableSqsValue"
accelerated_transcoding = "$AcceleratedTranscoding"

# Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    
    Set-Content -Path $tfvarsPath -Value $tfvarsContent
    Write-Host "terraform.tfvars created successfully" -ForegroundColor Green
}

# Function to run Terraform commands
function Invoke-Terraform {
    param(
        [string]$Command
    )
    
    Write-Host "Running: terraform $Command" -ForegroundColor Yellow
    
    Push-Location $IaCDir
    try {
        switch ($Command) {
            "init" {
                terraform init
            }
            "plan" {
                terraform plan -var-file="terraform.tfvars"
            }
            "apply" {
                terraform apply -var-file="terraform.tfvars" -auto-approve
            }
            "destroy" {
                terraform destroy -var-file="terraform.tfvars" -auto-approve
            }
            default {
                terraform $Command
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform command failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

# Main execution
try {
    # Step 1: Install Lambda dependencies
    Install-LambdaDependencies
    
    # Step 2: Create terraform.tfvars
    New-TerraformVars
    
    # Step 3: Initialize Terraform
    Invoke-Terraform "init"
    
    # Step 4: Execute the requested action
    switch ($Action) {
        "plan" {
            Write-Host "Running Terraform plan..." -ForegroundColor Yellow
            Invoke-Terraform "plan"
        }
        "apply" {
            Write-Host "Deploying infrastructure..." -ForegroundColor Yellow
            Invoke-Terraform "plan"
            
            # Confirm deployment
            $confirmation = Read-Host "Do you want to proceed with deployment? (y/N)"
            if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
                Invoke-Terraform "apply"
                Write-Host "Deployment completed successfully!" -ForegroundColor Green
            } else {
                Write-Host "Deployment cancelled by user" -ForegroundColor Yellow
            }
        }
        "destroy" {
            Write-Host "Destroying infrastructure..." -ForegroundColor Red
            
            # Confirm destruction
            $confirmation = Read-Host "Are you sure you want to destroy all resources? This action cannot be undone. (y/N)"
            if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
                Invoke-Terraform "destroy"
                Write-Host "Infrastructure destroyed successfully!" -ForegroundColor Green
            } else {
                Write-Host "Destruction cancelled by user" -ForegroundColor Yellow
            }
        }
    }
    
    # Step 5: Display outputs (for apply action)
    if ($Action -eq "apply") {
        Write-Host ""
        Write-Host "=== Deployment Outputs ===" -ForegroundColor Green
        Invoke-Terraform "output"
    }
    
} catch {
    Write-Error "Deployment failed: $_"
    exit 1
}

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host "Stack Name: $StackName" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan

if ($Action -eq "apply") {
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Verify MediaConvert job templates in the AWS Console" -ForegroundColor White
    Write-Host "2. Check MediaPackage packaging groups (if enabled)" -ForegroundColor White
    Write-Host "3. Test the video processing workflow" -ForegroundColor White
    Write-Host "4. Monitor CloudWatch logs for any issues" -ForegroundColor White
    Write-Host ""
    Write-Host "For troubleshooting, check:" -ForegroundColor Yellow
    Write-Host "- CloudFormation stack: $StackName-custom-resources" -ForegroundColor White
    Write-Host "- Lambda function: $StackName-custom-resource" -ForegroundColor White
    Write-Host "- CloudWatch logs: /aws/lambda/$StackName-custom-resource" -ForegroundColor White
}
