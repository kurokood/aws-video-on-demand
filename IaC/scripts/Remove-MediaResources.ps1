# Remove-MediaResources.ps1
# PowerShell script to remove MediaConvert templates and MediaPackage configuration
# Replaces CloudFormation custom resource deletion functionality

param(
    [Parameter(Mandatory=$true)]
    [string]$StackName,
    
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$false)]
    [bool]$EnableMediaPackage = $false
)

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Initialize AWS SDK
try {
    Import-Module AWSPowerShell -ErrorAction Stop
} catch {
    Write-Error "AWS PowerShell module not found. Please install it using: Install-Module -Name AWSPowerShell"
    exit 1
}

Write-Host "Starting MediaConvert and MediaPackage resource cleanup..."
Write-Host "Stack Name: $StackName"
Write-Host "Region: $Region"
Write-Host "Enable MediaPackage: $EnableMediaPackage"

try {
    # Step 1: Delete MediaConvert templates
    Write-Host "`n=== Deleting MediaConvert Templates ===" -ForegroundColor Yellow
    
    # Define template names based on MediaPackage setting
    $templateNames = @()
    
    if ($EnableMediaPackage) {
        # When MediaPackage is enabled, delete only MVOD templates
        $templateNames = @(
            "${StackName}_Ott_2160p_Avc_Aac_16x9_mvod_no_preset",
            "${StackName}_Ott_1080p_Avc_Aac_16x9_mvod_no_preset",
            "${StackName}_Ott_720p_Avc_Aac_16x9_mvod_no_preset"
        )
    } else {
        # When MediaPackage is disabled, delete only QVBR templates
        $templateNames = @(
            "${StackName}_Ott_2160p_Avc_Aac_16x9_qvbr_no_preset",
            "${StackName}_Ott_1080p_Avc_Aac_16x9_qvbr_no_preset",
            "${StackName}_Ott_720p_Avc_Aac_16x9_qvbr_no_preset"
        )
    }
    
    foreach ($templateName in $templateNames) {
        try {
            Write-Host "Deleting template: $templateName"
            Remove-MCJobTemplate -Name $templateName
            Write-Host "Successfully deleted template: $templateName"
        } catch {
            if ($_.Exception.Message -like "*NotFoundException*") {
                Write-Warning "Template $templateName not found (may have been already deleted)"
            } else {
                Write-Error "Error deleting template $templateName : $_"
            }
        }
    }
    
    Write-Host "MediaConvert templates cleanup completed!" -ForegroundColor Green
    
    # Step 2: Delete MediaPackage configuration (if enabled)
    if ($EnableMediaPackage) {
        Write-Host "`n=== Deleting MediaPackage VOD Configuration ===" -ForegroundColor Yellow
        
        $groupId = "${StackName}-packaging-group"
        
        # Delete packaging configurations first
        $configsToDelete = @(
            "${StackName}-hls-packaging-config",
            "${StackName}-dash-packaging-config",
            "${StackName}-mss-packaging-config",
            "${StackName}-cmaf-packaging-config"
        )
        
        foreach ($configId in $configsToDelete) {
            try {
                Write-Host "Deleting packaging configuration: $configId"
                Remove-MPVPackagingConfiguration -Id $configId
                Write-Host "Successfully deleted packaging configuration: $configId"
            } catch {
                if ($_.Exception.Message -like "*NotFoundException*") {
                    Write-Warning "Packaging configuration $configId not found (may have been already deleted)"
                } else {
                    Write-Error "Error deleting packaging configuration $configId : $_"
                }
            }
        }
        
        # Delete packaging group
        try {
            Write-Host "Deleting packaging group: $groupId"
            Remove-MPVPackagingGroup -Id $groupId
            Write-Host "Successfully deleted packaging group: $groupId"
        } catch {
            if ($_.Exception.Message -like "*NotFoundException*") {
                Write-Warning "Packaging group $groupId not found (may have been already deleted)"
            } else {
                Write-Error "Error deleting packaging group $groupId : $_"
            }
        }
        
        Write-Host "MediaPackage VOD configuration cleanup completed!" -ForegroundColor Green
    } else {
        Write-Host "MediaPackage VOD is disabled, skipping cleanup." -ForegroundColor Yellow
    }
    
    Write-Host "`n=== Cleanup Summary ===" -ForegroundColor Cyan
    Write-Host "✓ MediaConvert templates deleted"
    if ($EnableMediaPackage) {
        Write-Host "✓ MediaPackage VOD configuration deleted"
    }
    Write-Host "✓ All media resources cleaned up successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "Cleanup failed: $_"
    exit 1
}

Write-Host "`nMedia resource cleanup completed successfully!" -ForegroundColor Green
