# Video on Demand on AWS - Terraform Implementation

This directory contains the Terraform implementation of the AWS Video on Demand solution, equivalent to the CloudFormation template.

## Architecture

The Terraform configuration is organized into modules for better maintainability:

- **storage**: S3 buckets for source, destination, and logs
- **cloudfront**: CloudFront distribution for content delivery
- **database**: DynamoDB table for workflow tracking
- **messaging**: SNS and SQS for notifications and messaging
- **lambda**: Lambda functions for workflow processing
- **step_functions**: Step Functions state machines for orchestration
- **mediaconvert**: MediaConvert resources and roles
- **events**: EventBridge rules for workflow triggers

## Prerequisites

1. **Terraform**: Install Terraform >= 1.0
2. **AWS CLI**: Configure AWS credentials
3. **Lambda Code**: The actual Lambda function code needs to be packaged and uploaded to S3

## Deployment

1. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Update terraform.tfvars with your values:**
   ```hcl
   aws_region  = "us-east-1"
   stack_name  = "my-video-on-demand"
   admin_email = "your-email@example.com"
   ```

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Plan the deployment:**
   ```bash
   terraform plan
   ```

5. **Apply the configuration:**
   ```bash
   terraform apply
   ```

6. **Create MediaConvert templates and MediaPackage VOD resources:**
   ```powershell
   # Install Lambda dependencies first
   .\create-lambda-functions-dependencies.ps1
   
   # Create universal MediaConvert template (iOS and Android compatible)
   .\create-mediaconvert-templates.ps1 -StackName "your-stack-name" -EnableMediaPackage "Yes"
   
   # Create MediaPackage VOD resources (if MediaPackage is enabled)
   .\create-mediapackage-vod-groups.ps1 -StackName "your-stack-name"
   ```

## Important Notes

### Lambda Function Code

This Terraform configuration creates placeholder Lambda functions. In a production deployment, you need to:

1. Build the Lambda function code from the `lambda_functions` directory
2. Package the code into ZIP files
3. Upload to S3 or use Terraform's archive functionality
4. Update the Lambda function configurations to reference the actual code

### MediaConvert Templates and MediaPackage VOD

The MediaConvert job templates and MediaPackage VOD packaging groups are created using PowerShell scripts:

1. **MediaConvert Templates**: Run `create-mediaconvert-templates.ps1` to create a single universal CMAF template that supports both iOS and Android devices with adaptive bitrate streaming (2160p, 1080p, 720p, 540p, 360p). The template is defined in `templates/universal_cmaf_template.json`
2. **MediaPackage VOD**: Run `create-mediapackage-vod-groups.ps1` to create packaging groups and configurations

These scripts should be run after the Terraform deployment is complete.

### S3 Event Notifications

The S3 event notifications that trigger the workflow are not configured in this basic implementation. You'll need to add:

```hcl
resource "aws_s3_bucket_notification" "source_bucket_notification" {
  bucket = module.storage.source_bucket.id

  lambda_function {
    lambda_function_arn = module.lambda.step_functions_lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".mp4"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}
```

## Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region to deploy resources | `us-east-1` | No |
| `stack_name` | Name of the stack | `video-on-demand` | No |
| `admin_email` | Email for notifications | - | Yes |
| `workflow_trigger` | Workflow trigger type | `VideoFile` | No |
| `glacier` | Archive setting | `DISABLED` | No |
| `frame_capture` | Enable frame capture | `No` | No |
| `enable_media_package` | Enable MediaPackage | `No` | No |
| `enable_sns` | Enable SNS notifications | `Yes` | No |
| `enable_sqs` | Enable SQS messaging | `Yes` | No |
| `accelerated_transcoding` | MediaConvert acceleration | `PREFERRED` | No |

## Outputs

After deployment, Terraform will output:

- DynamoDB table name
- S3 bucket names (source, destination)
- CloudFront domain name
- SNS topic name
- SQS queue URL and ARN
- Solution UUID

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Differences from CloudFormation

1. **Modular Structure**: Organized into logical modules
2. **Type Safety**: Terraform provides better type checking
3. **State Management**: Terraform manages state differently than CloudFormation
4. **Resource Dependencies**: Explicit dependency management

## Next Steps

To make this production-ready:

1. Add the remaining Lambda functions
2. Implement MediaConvert template creation
3. Add S3 event notifications
4. Add Step Functions state machine definitions
5. Implement proper Lambda code deployment
6. Add monitoring and logging resources
7. Add security hardening (VPC, security groups, etc.)

## Validation and Troubleshooting

### Quick Validation
```bash
# Validate configuration
./validate.sh

# Check for common issues
terraform validate
terraform fmt -check
```

### Common Issues
See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions to common problems.

## Contributing

When adding new resources:

1. Follow the modular structure
2. Add appropriate variables and outputs
3. Include proper tags and naming conventions
4. Update this README with new variables/outputs
5. Test thoroughly before submitting