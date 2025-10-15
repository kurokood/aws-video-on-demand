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

```instructions
AI Coding Agent Instructions — fullstack-vod-architecture (concise)

Overview
- This repo implements an AWS Video-on-Demand pipeline orchestrated with Terraform (IaC) and Step Functions. Video processing is implemented as small Lambda functions under `IaC/lambda_functions/`. Terraform modules live in `IaC/modules/` and the main entry is `IaC/main.tf`.

Key components & data flow
- Step Functions: three state machines — ingest, process, publish. See `IaC/lambda_functions/step-functions/index.js` and `IaC/modules/step_functions/main.tf` for wiring.
- Lambdas: each function folder (e.g. `profiler`, `encode`, `dynamo-update`) is self-contained and packaged independently. Entrypoint: `exports.handler = async (event) => {}` and functions log input with console.log.
- Persistence & triggers: single DynamoDB table (single-table pattern, keyed by `guid`) updated by Lambdas; S3 object upload triggers the ingest flow; MediaConvert is used for encoding with templates managed by a CloudFormation custom resource (see `templates/vod-custom-resources-updated.yaml`).

Project-specific conventions (important)
- Terraform module pattern: resources are conditional (count = var.enable_feature ? 1 : 0). Look in `IaC/modules/*` for examples.
- Lambda packaging: each function has its own `package.json`. Use `IaC/install-lambda-dependencies.ps1` or run `npm install --production` inside the function folder before deploy.
- Env / naming: Terraform sets `SOLUTION_IDENTIFIER`, `AWS_NODEJS_CONNECTION_REUSE_ENABLED=1`, and an `ErrorHandler` ARN for Lambdas. Resource names use `${var.stack_name}-{service}-{descriptor}` and tags must include `SolutionId: "SO0021"`.
- Booleans passed from Terraform are strings in env vars — parse with `JSON.parse(process.env.SomeFlag)` in Node Lambdas.

Lambda + MediaConvert specifics
- Profiler selects the best template <= source resolution (see `IaC/lambda_functions/profiler/index.js`).
- Encode lambda sanitizes MediaConvert HLS output group ContainerSettings — only allow `Container` and `M3u8Settings` (see `IaC/lambda_functions/encode/index.js`).
- Always call `describeEndpoints()` to obtain the MediaConvert endpoint before submitting jobs.

Developer workflows (how to build, test, deploy)
- Install dependencies for all lambdas: run `IaC/install-lambda-dependencies.ps1` (Windows PowerShell).
- Validate Terraform changes (including lambda zips): `terraform plan` in `IaC/`.
- Deploy helper: `IaC/deploy.ps1` supports flags `-SkipDependencies` and `-SkipPlan` — inspect the script before running.

Examples & quick references
- Template selection: `IaC/lambda_functions/profiler/index.js` — shows resolution checks and fallback order: template → template_fixed → alternate_type → alternate_type_fixed.
- Encode job submission and sanitization: `IaC/lambda_functions/encode/index.js`.
- Custom resources: `IaC/lambda_functions/custom-resource/index.js` and `templates/vod-custom-resources-updated.yaml`.

When making changes
- If you update Lambda code, run `IaC/install-lambda-dependencies.ps1` then `terraform plan` to ensure the ZIPs changed as expected.
- Preserve minimal IAM — `IaC/modules/lambda/main.tf` shows the standard log policy and least-privilege pattern.

What this file should not contain
- Do not add high-level generic advice. Focus on reproducible, repo-specific steps and exact file references.

If anything is unclear or you'd like me to expand a section (examples, unit tests, CI steps), tell me which area to expand.
```