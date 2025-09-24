# Media Resources PowerShell Scripts

This directory contains PowerShell scripts that replace the CloudFormation custom resources for creating MediaConvert templates and MediaPackage VOD configuration.

## Scripts Overview

### 1. Deploy-MediaResources.ps1
Main orchestration script that creates both MediaConvert templates and MediaPackage configuration.

**Parameters:**
- `StackName` (required): Name of the VOD stack
- `Region` (required): AWS region
- `SourceBucketArn` (required): ARN of the source S3 bucket
- `DestinationBucketArn` (required): ARN of the destination S3 bucket
- `EnableMediaPackage` (optional): Enable MediaPackage VOD (default: false)
- `CloudFrontDistributionId` (optional): CloudFront distribution ID
- `MediaConvertRoleArn` (optional): MediaConvert service role ARN

### 2. Create-MediaConvertTemplates.ps1
Creates MediaConvert job templates for video processing.

**Features:**
- Creates resolution-specific templates (2160p, 1080p, 720p)
- Supports both QVBR (standard VOD) and MVOD (MediaPackage VOD) templates
- **MVOD templates now output HLS segments and manifest instead of CMAF**
- Uses adaptive bitrate (ABR) ladders for optimal quality

### 3. Create-MediaPackageConfiguration.ps1
Creates MediaPackage VOD packaging group and configurations.

**Features:**
- Creates packaging group
- Creates packaging configurations for HLS, DASH, MSS, and CMAF
- Integrates with CloudFront distribution (if provided)

### 4. Remove-MediaResources.ps1
Cleans up MediaConvert templates and MediaPackage configuration.

**Parameters:**
- `StackName` (required): Name of the VOD stack
- `Region` (required): AWS region
- `EnableMediaPackage` (optional): Enable MediaPackage VOD (default: false)

## Key Changes from CloudFormation Custom Resources

### MVOD Template Changes
- **Before**: MVOD templates used CMAF format with both HLS and DASH manifests
- **After**: MVOD templates use HLS format with M3U8 segments and manifest
- **Reason**: Simplified output format for better compatibility with MediaPackage VOD

### Template Structure
- **QVBR Templates**: Still use CMAF format for standard VOD processing
- **MVOD Templates**: Now use HLS format for MediaPackage VOD processing
- **Resolution-specific**: Each template is optimized for its source resolution (no upscaling)

## Prerequisites

1. **AWS PowerShell Module**: Install using `Install-Module -Name AWSPowerShell`
2. **AWS Credentials**: Configure using `Set-AWSCredential` or environment variables
3. **Permissions**: Ensure your AWS credentials have the necessary permissions for MediaConvert and MediaPackage VOD

## Usage

### Deploy Resources
```powershell
.\Deploy-MediaResources.ps1 -StackName "my-vod-stack" -Region "us-east-1" -SourceBucketArn "arn:aws:s3:::my-source-bucket" -DestinationBucketArn "arn:aws:s3:::my-destination-bucket" -EnableMediaPackage:$true
```

### Remove Resources
```powershell
.\Remove-MediaResources.ps1 -StackName "my-vod-stack" -Region "us-east-1" -EnableMediaPackage:$true
```

## Integration with Terraform

These scripts are called by the `media_resources` Terraform module using `null_resource` with `local-exec` provisioners. The scripts are executed during `terraform apply` and `terraform destroy` operations.

## Error Handling

- Scripts include comprehensive error handling
- Existing resources are detected and handled gracefully
- Detailed logging for troubleshooting
- Exit codes indicate success/failure status

## Template Naming Convention

Templates follow this naming pattern:
- QVBR: `{StackName}_Ott_{Resolution}p_Avc_Aac_16x9_qvbr_no_preset`
- MVOD: `{StackName}_Ott_{Resolution}p_Avc_Aac_16x9_mvod_no_preset`

Where `{Resolution}` is one of: 2160p, 1080p, 720p
