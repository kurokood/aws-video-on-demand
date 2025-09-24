# MediaConvert and MediaPackage Refactoring Summary

## Overview
This refactoring replaces the failing CloudFormation custom resources with PowerShell scripts for creating MediaConvert templates and MediaPackage VOD configuration. The key change is that MVOD templates now output HLS segments and manifest instead of CMAF.

## Changes Made

### 1. New PowerShell Scripts (`IaC/scripts/`)

#### Deploy-MediaResources.ps1
- Main orchestration script that calls other scripts
- Replaces CloudFormation custom resource functionality
- Handles both MediaConvert templates and MediaPackage configuration

#### Create-MediaConvertTemplates.ps1
- Creates MediaConvert job templates
- **Key Change**: MVOD templates now use HLS format instead of CMAF
- Supports resolution-specific templates (2160p, 1080p, 720p)
- Uses adaptive bitrate (ABR) ladders

#### Create-MediaPackageConfiguration.ps1
- Creates MediaPackage VOD packaging group and configurations
- Creates HLS, DASH, MSS, and CMAF packaging configurations
- Integrates with CloudFront distribution

#### Remove-MediaResources.ps1
- Cleans up MediaConvert templates and MediaPackage configuration
- Handles both creation and deletion scenarios

### 2. New Terraform Module (`IaC/modules/media_resources/`)

#### main.tf
- Replaces the `custom_resources` module
- Uses `null_resource` with `local-exec` provisioners to call PowerShell scripts
- Creates IAM roles and policies for MediaConvert and MediaPackage VOD
- Stores configuration details in SSM Parameter Store

#### variables.tf
- Defines input variables for the module
- Simplified compared to the original custom_resources module

#### outputs.tf
- Provides outputs for MediaConvert and MediaPackage resources
- Maintains backward compatibility with existing references

### 3. Updated Main Configuration (`IaC/main.tf`)

- Replaced `custom_resources` module with `media_resources` module
- Updated all references to use the new module
- Simplified module parameters

### 4. Updated Outputs (`IaC/outputs.tf`)

- Updated all output references to use `media_resources` module
- Removed references to CloudFormation stack outputs
- Updated monitoring links

### 5. Updated Documentation (`IaC/README.md`)

- Added PowerShell prerequisites
- Updated deployment instructions
- Documented the new automated approach
- Explained the MVOD template changes

## Key Technical Changes

### MVOD Template Format Change
- **Before**: MVOD templates used CMAF format with both HLS and DASH manifests
- **After**: MVOD templates use HLS format with M3U8 segments and manifest
- **Reason**: Simplified output format for better compatibility with MediaPackage VOD

### Template Structure
- **QVBR Templates**: Still use CMAF format for standard VOD processing
- **MVOD Templates**: Now use HLS format for MediaPackage VOD processing
- **Resolution-specific**: Each template is optimized for its source resolution (no upscaling)

### PowerShell Integration
- Scripts are called automatically during `terraform apply` and `terraform destroy`
- Comprehensive error handling and logging
- Graceful handling of existing resources
- Exit codes indicate success/failure status

## Benefits

1. **Reliability**: Eliminates CloudFormation custom resource failures
2. **Simplicity**: PowerShell scripts are easier to debug and maintain
3. **Flexibility**: Scripts can be run independently for testing
4. **Compatibility**: MVOD templates now use standard HLS format
5. **Automation**: No manual script execution required

## Migration Path

1. **Existing Deployments**: 
   - Run `terraform destroy` to remove old custom resources
   - Update Terraform configuration
   - Run `terraform apply` to deploy new resources

2. **New Deployments**:
   - Use the updated configuration directly
   - PowerShell scripts will run automatically

## Prerequisites

- Windows PowerShell 5.1+ or PowerShell Core 6.0+
- AWS PowerShell Module: `Install-Module -Name AWSPowerShell`
- Proper AWS credentials and permissions

## Files Modified

### New Files
- `IaC/scripts/Deploy-MediaResources.ps1`
- `IaC/scripts/Create-MediaConvertTemplates.ps1`
- `IaC/scripts/Create-MediaPackageConfiguration.ps1`
- `IaC/scripts/Remove-MediaResources.ps1`
- `IaC/scripts/README.md`
- `IaC/modules/media_resources/main.tf`
- `IaC/modules/media_resources/variables.tf`
- `IaC/modules/media_resources/outputs.tf`
- `IaC/REFACTORING_SUMMARY.md`

### Modified Files
- `IaC/main.tf`
- `IaC/outputs.tf`
- `IaC/README.md`

### Deprecated Files
- `IaC/modules/custom_resources/` (can be removed after migration)
- `IaC/templates/vod-custom-resources-updated.yaml` (no longer used)
- `IaC/lambda_functions/custom-resource/` (no longer used)

## Testing

The refactored solution should be tested with:
1. Fresh deployment using `terraform apply`
2. Resource cleanup using `terraform destroy`
3. Manual script execution for troubleshooting
4. Verification of MediaConvert templates in AWS console
5. Verification of MediaPackage VOD configuration

## Rollback Plan

If issues arise, the system can be rolled back by:
1. Reverting to the original `custom_resources` module
2. Restoring the original `main.tf` and `outputs.tf` files
3. Running the original PowerShell scripts manually
4. Cleaning up any resources created by the new scripts
