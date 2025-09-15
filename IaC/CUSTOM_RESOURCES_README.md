# Custom Resources Implementation for Video on Demand

This implementation provides MediaConvert and MediaPackage VOD resources through CloudFormation custom resources deployed via Terraform. It replicates all the functionality from the original AWS Video on Demand Solution v6.1.13.

## Architecture Overview

The custom resources approach consists of:

1. **Custom Resource Lambda Function** - Handles creation/deletion of MediaConvert templates and MediaPackage resources
2. **CloudFormation Stack** - Deployed via Terraform, contains all custom resource definitions
3. **Service Roles** - IAM roles for MediaConvert and MediaPackage services
4. **Template Configurations** - All resolution variants (2160p, 1080p, 720p) with QVBR and MVOD types

## Features Implemented

### MediaConvert Templates

Based on the original CloudFormation template, the following job templates are created:

#### Standard Resolution Templates
- **2160p (4K UHD)**: 3840x2160, up to 15Mbps, QVBR Quality Level 9
- **1080p (Full HD)**: 1920x1080, up to 8.5Mbps, QVBR Quality Level 8  
- **720p (HD)**: 1280x720, up to 6Mbps, QVBR Quality Level 8

#### Universal CMAF Template
- **Multi-resolution adaptive**: Includes 2160p, 1080p, 720p, 540p, 360p variants
- **Single template approach**: All resolutions in one job template
- **iOS/Android compatible**: Universal CMAF format

#### Template Types
- **QVBR Templates**: Quality-defined Variable Bitrate for general use
- **MVOD Templates**: Created when MediaPackage is enabled for VOD packaging

### MediaPackage VOD Resources

When MediaPackage is enabled, the following resources are created:

#### Packaging Group
- **Group ID**: `{stack-name}-packaging-group`
- **Domain**: Auto-generated MediaPackage domain
- **Integration**: Linked with CloudFront distribution

#### Packaging Configurations
- **HLS**: Traditional HTTP Live Streaming
- **DASH**: Dynamic Adaptive Streaming over HTTP
- **MSS**: Microsoft Smooth Streaming  
- **CMAF**: Common Media Application Format

### Video Encoding Settings

All templates use these optimized settings from the original solution:

#### Video Codec (H.264)
```json
{
  "Codec": "H_264",
  "Profile": "HIGH", 
  "Level": "AUTO",
  "RateControlMode": "QVBR",
  "QualityTuningLevel": "MULTI_PASS_HQ",
  "AdaptiveQuantization": "HIGH",
  "SpatialAdaptiveQuantization": "ENABLED",
  "TemporalAdaptiveQuantization": "ENABLED",
  "GopSize": 60,
  "NumberReferenceFrames": 3,
  "NumberBFramesBetweenReferenceFrames": 2
}
```

#### Audio Codec (AAC)
```json
{
  "Codec": "AAC",
  "Profile": "LC",
  "SampleRate": 48000,
  "Bitrate": 128000,
  "Channels": 2,
  "CodingMode": "CODING_MODE_2_0"
}
```

## Usage

### 1. Deploy the Infrastructure

```bash
cd IaC
terraform init
terraform plan
terraform apply
```

### 2. Configuration Parameters

The module accepts the same parameters as the original solution:

```hcl
module "custom_resources" {
  source = "./modules/custom_resources"

  stack_name                  = "my-vod-stack"
  admin_email                 = "admin@example.com"
  workflow_trigger            = "VideoFile"          # or "MetadataFile"
  glacier                     = "DISABLED"           # or "GLACIER", "DEEP_ARCHIVE"
  frame_capture              = false                 # Enable frame capture
  enable_media_package       = false                 # Enable MediaPackage VOD
  enable_sns                 = true                  # Enable SNS notifications
  enable_sqs                 = true                  # Enable SQS messaging
  accelerated_transcoding    = "PREFERRED"           # or "ENABLED", "DISABLED"
  source_bucket_arn          = "arn:aws:s3:::source-bucket"
  destination_bucket_arn     = "arn:aws:s3:::dest-bucket"
  cloudfront_distribution_id = "E1234567890123"
}
```

### 3. Template Selection Logic

The system automatically selects the appropriate template based on configuration:

#### Without MediaPackage (QVBR Templates)
- `{stack-name}_Ott_2160p_Avc_Aac_16x9_qvbr_no_preset`
- `{stack-name}_Ott_1080p_Avc_Aac_16x9_qvbr_no_preset`
- `{stack-name}_Ott_720p_Avc_Aac_16x9_qvbr_no_preset`
- `{stack-name}_Ott_universal_Avc_Aac_16x9_qvbr_no_preset`

#### With MediaPackage (MVOD Templates)
- `{stack-name}_Ott_2160p_Avc_Aac_16x9_mvod_no_preset`
- `{stack-name}_Ott_1080p_Avc_Aac_16x9_mvod_no_preset`
- `{stack-name}_Ott_720p_Avc_Aac_16x9_mvod_no_preset`
- `{stack-name}_Ott_universal_Avc_Aac_16x9_mvod_no_preset`

## Template Specifications

### 2160p Template Settings
- **Resolution**: 3840x2160
- **Max Bitrate**: 15,000,000 bps
- **QVBR Quality**: Level 9
- **GOP Size**: 60 frames
- **Container**: CMFC (CMAF Container)

### 1080p Template Settings
- **Resolution**: 1920x1080  
- **Max Bitrate**: 8,500,000 bps
- **QVBR Quality**: Level 8
- **GOP Size**: 60 frames
- **Container**: CMFC (CMAF Container)

### 720p Template Settings
- **Resolution**: 1280x720
- **Max Bitrate**: 6,000,000 bps
- **QVBR Quality**: Level 8
- **GOP Size**: 60 frames
- **Container**: CMFC (CMAF Container)

### Universal CMAF Template Settings
Includes all the above resolutions plus:
- **540p**: 960x540, 3.5Mbps, Quality Level 7
- **360p**: 640x360, 1.5Mbps, Quality Level 7

## Outputs

The module provides comprehensive outputs for integration:

### MediaConvert Outputs
```hcl
output "mediaconvert_endpoint_url" {
  description = "MediaConvert endpoint URL"
}

output "mediaconvert_role_arn" {
  description = "MediaConvert service role ARN"
}

output "template_2160p_qvbr" {
  description = "2160p QVBR template name"
}

# ... additional template names
```

### MediaPackage Outputs (when enabled)
```hcl
output "mediapackage_group_id" {
  description = "MediaPackage VOD packaging group ID"
}

output "mediapackage_group_domain_name" {
  description = "MediaPackage VOD domain name"
}

output "mediapackage_vod_role_arn" {
  description = "MediaPackage VOD service role ARN"
}
```

## Comparison with Original Solution

| Feature | Original CloudFormation | This Implementation |
|---------|------------------------|-------------------|
| MediaConvert Templates | ✅ All resolutions | ✅ All resolutions |
| MediaPackage VOD | ✅ Full support | ✅ Full support |
| Template Types | ✅ QVBR + MVOD | ✅ QVBR + MVOD |
| Universal CMAF | ✅ Included | ✅ Included |
| Service Roles | ✅ Managed | ✅ Managed |
| Conditional Resources | ✅ MediaPackage conditions | ✅ MediaPackage conditions |
| Cleanup | ✅ Automatic | ✅ Automatic |
| Deployment Method | CloudFormation only | Terraform + CloudFormation |

## File Structure

```
IaC/
├── modules/custom_resources/
│   ├── main.tf                    # Main Terraform configuration
│   ├── variables.tf               # Input variables
│   └── outputs.tf                 # Output values
├── lambda_functions/custom-resource/
│   ├── index.js                   # Custom resource Lambda function
│   └── package.json               # Lambda dependencies
├── templates/
│   ├── vod-custom-resources.yaml  # CloudFormation template
│   └── universal_cmaf_template.json # CMAF template specification
└── CUSTOM_RESOURCES_README.md     # This documentation
```

## Benefits

1. **Complete Feature Parity**: All original solution features implemented
2. **Terraform Integration**: Seamless integration with existing Terraform infrastructure
3. **Flexibility**: Easy to customize and extend
4. **Reliability**: Based on proven AWS Solutions architecture
5. **Maintainability**: Clear separation of concerns between Terraform and CloudFormation

## Troubleshooting

### Common Issues

1. **Template Creation Fails**
   - Check MediaConvert service limits
   - Verify IAM permissions for custom resource Lambda
   - Review CloudWatch logs for custom resource function

2. **MediaPackage Resources Not Created**
   - Ensure `enable_media_package = true`
   - Verify MediaPackage VOD is available in your region
   - Check custom resource Lambda permissions

3. **CloudFormation Stack Updates Fail**
   - Review stack events in CloudFormation console
   - Check custom resource Lambda timeout (300 seconds)
   - Verify resource dependencies

### Monitoring

- **CloudWatch Logs**: `/aws/lambda/{stack-name}-custom-resource`
- **CloudFormation Events**: Monitor stack events for custom resource operations
- **MediaConvert Console**: Verify job templates are created successfully
- **MediaPackage Console**: Verify packaging groups and configurations

## Migration from Existing Infrastructure

If migrating from the existing modules:

1. **Remove old module calls** from main.tf
2. **Add custom_resources module** call
3. **Update variable references** to use new module outputs
4. **Run terraform plan** to verify changes
5. **Apply changes** with `terraform apply`

The custom resources approach provides a comprehensive, production-ready solution that maintains full compatibility with the original AWS Video on Demand Solution while providing the flexibility and maintainability of Terraform.
