# Deploy-MediaResources.ps1
# Main PowerShell script to deploy MediaConvert templates and MediaPackage configuration
# Replaces CloudFormation custom resource functionality

param(
    [Parameter(Mandatory=$true)]
    [string]$StackName,
    
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$true)]
    [string]$SourceBucketArn,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationBucketArn,
    
    [Parameter(Mandatory=$false)]
    [bool]$EnableMediaPackage = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$CloudFrontDistributionId = "",
    
    [Parameter(Mandatory=$false)]
    [string]$MediaConvertRoleArn = ""
)

Write-Host "Starting MediaConvert and MediaPackage resource deployment..."
Write-Host "Stack Name: $StackName"
Write-Host "Region: $Region"
Write-Host "Enable MediaPackage: $EnableMediaPackage"

# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

try {
    # Step 1: Create MediaConvert templates
    Write-Host "`n=== Creating MediaConvert Templates ===" -ForegroundColor Green
    
    $mediaconvertParams = @{
        StackName = $StackName
        Region = $Region
        SourceBucketArn = $SourceBucketArn
        DestinationBucketArn = $DestinationBucketArn
        EnableMediaPackage = $EnableMediaPackage
        MediaConvertRoleArn = $MediaConvertRoleArn
    }
    
    & "$scriptDir\Create-MediaConvertTemplates.ps1" @mediaconvertParams
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create MediaConvert templates"
    }
    
    Write-Host "MediaConvert templates created successfully!" -ForegroundColor Green
    
    # Step 2: Create MediaPackage configuration (if enabled)
    if ($EnableMediaPackage) {
        Write-Host "`n=== Creating MediaPackage VOD Configuration ===" -ForegroundColor Green
        
        $mediapackageParams = @{
            StackName = $StackName
            Region = $Region
            DestinationBucketArn = $DestinationBucketArn
            CloudFrontDistributionId = $CloudFrontDistributionId
        }
        
        & "$scriptDir\Create-MediaPackageConfiguration.ps1" @mediapackageParams
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create MediaPackage configuration"
        }
        
        Write-Host "MediaPackage VOD configuration created successfully!" -ForegroundColor Green
    } else {
        Write-Host "MediaPackage VOD is disabled, skipping configuration." -ForegroundColor Yellow
    }
    
    Write-Host "`n=== Deployment Summary ===" -ForegroundColor Cyan
    Write-Host "✓ MediaConvert templates created"
    if ($EnableMediaPackage) {
        Write-Host "✓ MediaPackage VOD configuration created"
    }
    Write-Host "✓ All media resources deployed successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "Deployment failed: $_"
    exit 1
}

Write-Host "`nMedia resource deployment completed successfully!" -ForegroundColor Green
