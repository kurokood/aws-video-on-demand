# Custom Resources Module for MediaConvert and MediaPackage
# Deploys CloudFormation stack with custom resources

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Terraform providers needed
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Create ZIP file for Lambda function
data "archive_file" "custom_resource_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda_functions/custom-resource"
  output_path = "${path.module}/../lambda/lambda_zips/custom_resource.zip"
  
  depends_on = [null_resource.install_custom_resource_dependencies]
}

# Local variables
locals {
  lambda_bucket_name = "${var.stack_name}-lambda-code-${random_id.bucket_suffix.hex}"
}

# Random suffix for unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket for Lambda code
resource "aws_s3_bucket" "lambda_code" {
  bucket = local.lambda_bucket_name

  tags = {
    Name       = "${var.stack_name}-lambda-code"
    SolutionId = "SO0021"
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "lambda_code" {
  bucket = aws_s3_bucket.lambda_code.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Install Lambda dependencies
resource "null_resource" "install_custom_resource_dependencies" {
  triggers = {
    package_json = filemd5("${path.module}/../../lambda_functions/custom-resource/package.json")
  }

  provisioner "local-exec" {
    command = "cd ${path.module}/../../lambda_functions/custom-resource && npm install --production"
  }
}

# Upload Lambda code to S3
resource "aws_s3_object" "custom_resource_code" {
  bucket = aws_s3_bucket.lambda_code.bucket
  key    = "custom-resource.zip"
  source = data.archive_file.custom_resource_zip.output_path
  etag   = data.archive_file.custom_resource_zip.output_md5

  depends_on = [
    null_resource.install_custom_resource_dependencies,
    data.archive_file.custom_resource_zip
  ]
}

# CloudFormation stack for custom resources
resource "aws_cloudformation_stack" "vod_custom_resources" {
  name = "${var.stack_name}-custom-resources"

  parameters = {
    StackName                  = var.stack_name
    AdminEmail                 = var.admin_email
    WorkflowTrigger           = var.workflow_trigger
    Glacier                   = var.glacier
    FrameCapture             = var.frame_capture ? "Yes" : "No"
    EnableMediaPackage       = var.enable_media_package ? "Yes" : "No"
    EnableSns                = var.enable_sns ? "Yes" : "No"
    EnableSqs                = var.enable_sqs ? "Yes" : "No"
    AcceleratedTranscoding   = var.accelerated_transcoding
    SourceBucketArn          = var.source_bucket_arn
    DestinationBucketArn     = var.destination_bucket_arn
    CloudFrontDistributionId = var.cloudfront_distribution_id
    LambdaCodeBucket         = local.lambda_bucket_name
    LambdaCodeKey           = aws_s3_object.custom_resource_code.key
  }

  template_body = file("${path.module}/../../templates/vod-custom-resources-updated.yaml")

  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  tags = {
    Name       = "${var.stack_name}-custom-resources"
    SolutionId = "SO0021"
  }

  depends_on = [
    aws_s3_object.custom_resource_code
  ]
}

# Lambda function is created by CloudFormation stack, not Terraform
# This avoids naming conflicts and allows CloudFormation to manage the complete lifecycle

# IAM Role for Custom Resource Lambda
resource "aws_iam_role" "custom_resource_role" {
  name = "${var.stack_name}-custom-resource-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name       = "${var.stack_name}-custom-resource-role"
    SolutionId = "SO0021"
  }
}

# IAM Policy for Custom Resource Lambda
resource "aws_iam_policy" "custom_resource_policy" {
  name = "${var.stack_name}-custom-resource-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutBucketNotification",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = var.source_bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "mediaconvert:CreatePreset",
          "mediaconvert:CreateJobTemplate",
          "mediaconvert:DeletePreset",
          "mediaconvert:DeleteJobTemplate",
          "mediaconvert:DescribeEndpoints",
          "mediaconvert:ListJobTemplates",
          "mediaconvert:TagResource",
          "mediaconvert:UntagResource"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:mediaconvert:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "mediapackage-vod:CreateAsset",
          "mediapackage-vod:CreatePackagingConfiguration",
          "mediapackage-vod:CreatePackagingGroup",
          "mediapackage-vod:DeleteAsset",
          "mediapackage-vod:DeletePackagingConfiguration",
          "mediapackage-vod:DeletePackagingGroup",
          "mediapackage-vod:DescribePackagingGroup",
          "mediapackage-vod:ListAssets",
          "mediapackage-vod:ListPackagingConfigurations",
          "mediapackage-vod:ListPackagingGroups",
          "mediapackage-vod:TagResource",
          "mediapackage-vod:UntagResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistributionConfig",
          "cloudfront:UpdateDistribution"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"
      }
    ]
  })

  tags = {
    Name       = "${var.stack_name}-custom-resource-policy"
    SolutionId = "SO0021"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "custom_resource_policy_attachment" {
  role       = aws_iam_role.custom_resource_role.name
  policy_arn = aws_iam_policy.custom_resource_policy.arn
}

# CloudWatch Log Group for Custom Resource Lambda
resource "aws_cloudwatch_log_group" "custom_resource_logs" {
  name              = "/aws/lambda/${var.stack_name}-custom-resource"
  retention_in_days = 14

  tags = {
    Name       = "${var.stack_name}-custom-resource-logs"
    SolutionId = "SO0021"
  }
}

# Lambda code is managed via S3 upload and CloudFormation parameters
# No need for separate update resource since CloudFormation handles the lifecycle

# CloudFormation template is used as-is with S3 code reference

# MediaConvert Service Role (outside CloudFormation for Terraform integration)
resource "aws_iam_role" "mediaconvert_role" {
  name = "${var.stack_name}-mediaconvert-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name       = "${var.stack_name}-mediaconvert-service-role"
    SolutionId = "SO0021"
  }
}

# MediaConvert Service Policy
resource "aws_iam_policy" "mediaconvert_policy" {
  name = "${var.stack_name}-mediaconvert-service-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${var.source_bucket_arn}/*",
          "${var.destination_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = "execute-api:Invoke"
        Resource = "arn:${data.aws_partition.current.partition}:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })

  tags = {
    Name       = "${var.stack_name}-mediaconvert-service-policy"
    SolutionId = "SO0021"
  }
}

# Attach MediaConvert policy to role
resource "aws_iam_role_policy_attachment" "mediaconvert_policy_attachment" {
  role       = aws_iam_role.mediaconvert_role.name
  policy_arn = aws_iam_policy.mediaconvert_policy.arn
}

# MediaPackage VOD Service Role (if enabled)
resource "aws_iam_role" "mediapackage_vod_role" {
  count = var.enable_media_package ? 1 : 0
  name  = "${var.stack_name}-mediapackage-vod-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "mediapackage.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name       = "${var.stack_name}-mediapackage-vod-service-role"
    SolutionId = "SO0021"
  }
}

# MediaPackage VOD Service Policy
resource "aws_iam_policy" "mediapackage_vod_policy" {
  count = var.enable_media_package ? 1 : 0
  name  = "${var.stack_name}-mediapackage-vod-service-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:GetBucketRequestPayment"
        ]
        Resource = [
          var.destination_bucket_arn,
          "${var.destination_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name       = "${var.stack_name}-mediapackage-vod-service-policy"
    SolutionId = "SO0021"
  }
}

# Attach MediaPackage VOD policy to role
resource "aws_iam_role_policy_attachment" "mediapackage_vod_policy_attachment" {
  count      = var.enable_media_package ? 1 : 0
  role       = aws_iam_role.mediapackage_vod_role[0].name
  policy_arn = aws_iam_policy.mediapackage_vod_policy[0].arn
}
