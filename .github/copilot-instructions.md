# AI Coding Agent Instructions - VOD Architecture

## Project Overview
This is an **AWS Video on Demand (VOD) solution** using Terraform IaC. It processes video uploads through a 3-stage Step Functions workflow: **Ingest → Process → Publish**.

## Architecture Patterns

### Modular Terraform Structure
- **Main config**: `IaC/main.tf` - orchestrates all modules
- **Module pattern**: Each AWS service group has its own module in `IaC/modules/`
- **Conditional resources**: Use `count = var.enable_feature ? 1 : 0` pattern consistently
- **Data sources**: Always include `aws_caller_identity`, `aws_region`, `aws_partition` for ARN construction

### Lambda Function Conventions
- **Location**: All functions in `IaC/lambda_functions/{function-name}/`
- **Entry point**: Always `exports.handler = async (event) => {}`
- **Error handling**: Use `ErrorHandler` Lambda ARN from environment variables
- **Logging**: Start with `console.log(\`REQUEST:: ${JSON.stringify(event, null, 2)}\`)`
- **Dependencies**: Each function has own `package.json` with specific AWS SDK v3 imports

### Step Functions Workflow Pattern
Three state machines with specific responsibilities:
```
ingest (input-validate → mediainfo → dynamo-update → process-execute)
process (profiler → encode-job-submit → dynamo-update)  
publish (output-validate → archive → mediapackage → notifications)
```
- Use `jsondecode(local.condition ? jsonencode(task) : jsonencode(pass))` for conditional steps
- All tasks have identical retry configuration with exponential backoff

## Critical Development Workflows

### Deployment Commands
```powershell
# Full deployment
.\IaC\deploy.ps1

# Skip Lambda dependencies (faster iteration)
.\IaC\deploy.ps1 -SkipDependencies

# Skip plan for quick deployment
.\IaC\deploy.ps1 -SkipPlan

# Install only Lambda dependencies
.\IaC\create-lambda-functions-dependencies.ps1
```

### Lambda Development
- **Dependencies**: Always run `npm install --production` in function directory
- **Testing**: Use `terraform plan` to validate Lambda ZIP changes
- **Code pattern**: Functions receive event data, update it, and pass to next step

### Template Selection Logic
The profiler Lambda selects MediaConvert templates based on source resolution to prevent upscaling:
```javascript
// Pattern: Choose highest template that doesn't exceed source resolution
if (srcHeight >= 2160 && srcWidth >= 3840) return template2160p;
else if (srcHeight >= 1080 && srcWidth >= 1920) return template1080p;
```

## Integration Points

### State Management
- **DynamoDB**: Single table tracks all workflow state using `guid` as primary key
- **Event flow**: Each Lambda updates DynamoDB, next step reads current state
- **Pattern**: Always include `event.guid` for workflow correlation

### S3 Event Triggers
- **Source bucket**: Triggers on video file uploads (12+ supported formats)
- **Metadata mode**: JSON files override default workflow configuration  
- **Pattern**: Use `decodeURIComponent(key.replace(/\+/g, " "))` for S3 key handling

### MediaConvert Integration
- **Template fallback**: Try `template → template_fixed → alternate_type → alternate_type_fixed`
- **Endpoint resolution**: Always call `describeEndpoints()` for account-specific endpoint
- **Output paths**: Use sanitized filename: `filename.replace(/[^a-zA-Z0-9_-]/g, '_')`

### IAM Permissions Pattern
Each Lambda has minimal permissions:
```terraform
# Standard pattern for all Lambda IAM policies
{
  Effect = "Allow"
  Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
  Resource = "arn:${data.aws_partition.current.partition}:logs:*"
}
```

## Project-Specific Conventions

### Resource Naming
- **Format**: `${var.stack_name}-{service}-{descriptor}`
- **Example**: `vod-step-functions-service-role`
- **Tags**: Always include `Name` and `SolutionId: "SO0021"`

### Environment Variables in Lambda
- **SOLUTION_IDENTIFIER**: For AWS SDK user agent tracking
- **AWS_NODEJS_CONNECTION_REUSE_ENABLED**: Always set to "1"
- **ErrorHandler**: ARN reference for centralized error handling

### Custom Resource Pattern
Uses CloudFormation stack within Terraform for MediaConvert template creation:
- **Lambda code**: Uploaded to S3, referenced by CloudFormation
- **Templates**: Created via custom resource, not Terraform MediaConvert resources
- **Reason**: MediaConvert templates need complex JSON configurations

### Conditional Features
Use environment variable parsing in Lambda:
```javascript
enableMediaPackage: JSON.parse(process.env.EnableMediaPackage)
```
Terraform passes boolean as string, Lambda parses back to boolean.

## Key Files Reference
- `IaC/main.tf`: Module orchestration and conditional logic
- `IaC/modules/lambda/main.tf`: Lambda function definitions and IAM policies  
- `IaC/modules/step_functions/main.tf`: Workflow state machine definitions
- `IaC/lambda_functions/profiler/index.js`: Template selection logic
- `IaC/lambda_functions/encode/index.js`: MediaConvert job submission with fallbacks
- `terraform.tfvars`: Current deployment configuration