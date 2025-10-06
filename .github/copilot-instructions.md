ingest (input-validate → mediainfo → dynamo-update → process-execute)
process (profiler → encode-job-submit → dynamo-update)  
publish (output-validate → archive → mediapackage → notifications)
# AI Coding Agent Instructions – VOD Architecture

## Project Overview
This project implements an **AWS Video on Demand (VOD) pipeline** using Terraform. It orchestrates video processing via Step Functions, Lambda, S3, DynamoDB, and MediaConvert, following a modular, production-grade architecture.

## Architecture & Data Flow
- **Terraform Modules**: Each AWS service group is a module under `IaC/modules/`. The main orchestrator is `IaC/main.tf`.
- **Step Functions**: Three state machines: `ingest`, `process`, `publish`. Each is a linear workflow of Lambda tasks (see below for order).
- **Lambdas**: All code in `IaC/lambda_functions/{function}/`. Each function is self-contained with its own `package.json` and only required AWS SDK v3 imports.
- **DynamoDB**: Single-table design, keyed by `guid`, tracks workflow state. Every Lambda reads/updates this table.
- **S3**: Source bucket triggers workflow on video upload. Metadata JSON files can override workflow config.
- **MediaConvert**: Templates are managed via a custom resource (see below). Output group and container settings must strictly match AWS schema.

## Key Patterns & Conventions
- **Module Pattern**: All resources are conditionally created using `count = var.enable_feature ? 1 : 0`.
- **Data Sources**: Always use `aws_caller_identity`, `aws_region`, `aws_partition` for ARNs.
- **Lambda Entrypoint**: Always `exports.handler = async (event) => {}`. Log input with `console.log(\`REQUEST:: ${JSON.stringify(event, null, 2)}\`)`.
- **Error Handling**: All Lambdas use an `ErrorHandler` Lambda ARN from env vars.
- **IAM**: Lambdas get minimal permissions. See `modules/lambda/main.tf` for the standard log policy block.
- **Resource Naming**: `${var.stack_name}-{service}-{descriptor}`. Tag every resource with `Name` and `SolutionId: "SO0021"`.
- **Environment Variables**: Always set `SOLUTION_IDENTIFIER`, `AWS_NODEJS_CONNECTION_REUSE_ENABLED=1`, and `ErrorHandler` in Lambda env.
- **Conditional Features**: Pass booleans as strings from Terraform, parse in Lambda with `JSON.parse(process.env.EnableMediaPackage)`.

## Step Functions Workflows
**ingest**: input-validate → mediainfo → dynamo-update → process-execute  
**process**: profiler → encode-job-submit → dynamo-update  
**publish**: output-validate → archive → mediapackage → notifications
- Use `jsondecode(local.condition ? jsonencode(task) : jsonencode(pass))` for conditional steps.
- All tasks use identical retry config (exponential backoff).

## Lambda & MediaConvert Integration
- **Template Selection**: Profiler Lambda chooses the highest template not exceeding source resolution (see `profiler/index.js`).
- **Encode Lambda**: Always sanitize HLS output group `ContainerSettings` to only allow `Container` and `M3u8Settings` (see `encode/index.js`).
- **Template Fallback**: Try `template → template_fixed → alternate_type → alternate_type_fixed`.
- **Output Paths**: Sanitize filenames: `filename.replace(/[^a-zA-Z0-9_-]/g, '_')`.
- **Endpoint**: Always call `describeEndpoints()` for MediaConvert endpoint.

## Custom Resource Pattern
- MediaConvert templates are created via a CloudFormation custom resource (not Terraform native). Lambda code is uploaded to S3 and referenced by CloudFormation. See `modules/custom_resources/` and `templates/vod-custom-resources-updated.yaml`.

## Developer Workflows
- **Deploy**: Use `IaC/deploy.ps1` (see script for flags: `-SkipDependencies`, `-SkipPlan`).
- **Install Lambda Deps**: Run `IaC/install-lambda-dependencies.ps1` or `npm install --production` in each function dir.
- **Test**: Use `terraform plan` to validate Lambda ZIP changes.

## Key Files & References
- `IaC/main.tf`: Module orchestration
- `IaC/modules/lambda/main.tf`: Lambda/IAM definitions
- `IaC/modules/step_functions/main.tf`: State machine definitions
- `IaC/lambda_functions/profiler/index.js`: Template selection logic
- `IaC/lambda_functions/encode/index.js`: MediaConvert job submission & sanitization
- `templates/vod-custom-resources-updated.yaml`: Custom resource for MediaConvert templates
- `terraform.tfvars`: Deployment config