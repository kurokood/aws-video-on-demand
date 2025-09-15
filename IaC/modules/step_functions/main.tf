# Step Functions module for Video on Demand

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Local values for conditional state definitions  
locals {
  # Use conditional blocks to build different state definitions
  enable_mediapackage = var.enable_media_package && var.lambda_functions.media_package_assets != null
}

# Step Functions Service Role
resource "aws_iam_role" "step_functions_service_role" {
  name = "${var.stack_name}-stepfunctions-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.${data.aws_region.current.name}.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.stack_name}-stepfunctions-service-role"
  }
}

resource "aws_iam_policy" "step_functions_service_policy" {
  name = "${var.stack_name}-stepfunctions-service-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_functions_service_policy_attachment" {
  role       = aws_iam_role.step_functions_service_role.name
  policy_arn = aws_iam_policy.step_functions_service_policy.arn
}

# Ingest Workflow State Machine
resource "aws_sfn_state_machine" "ingest_workflow" {
  name     = "${var.stack_name}-ingest"
  role_arn = aws_iam_role.step_functions_service_role.arn

  definition = jsonencode({
    StartAt = "Input Validate"
    States = {
      "Input Validate" = {
        Type     = "Task"
        Resource = var.lambda_functions.input_validate.arn
        Next     = "MediaInfo"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "MediaInfo" = {
        Type     = "Task"
        Resource = var.lambda_functions.mediainfo.arn
        Next     = "DynamoDB Update (Ingest)"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "DynamoDB Update (Ingest)" = {
        Type     = "Task"
        Resource = var.lambda_functions.dynamo_update.arn
        Next     = "SNS Choice (Ingest)"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "SNS Choice (Ingest)" = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.enableSns"
            BooleanEquals = true
            Next          = "SNS Notification (Ingest)"
          }
        ]
        Default = "Process Execute"
      }
      "SNS Notification (Ingest)" = {
        Type     = "Task"
        Resource = var.lambda_functions.sns_notification.arn
        Next     = "Process Execute"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "Process Execute" = {
        Type     = "Task"
        Resource = var.step_functions_lambda_arn
        End      = true
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
    }
  })

  tags = {
    Name = "${var.stack_name}-ingest"
  }
}

# Process Workflow State Machine
resource "aws_sfn_state_machine" "process_workflow" {
  name     = "${var.stack_name}-process"
  role_arn = aws_iam_role.step_functions_service_role.arn

  definition = jsonencode({
    StartAt = "Profiler"
    States = {
      "Profiler" = {
        Type     = "Task"
        Resource = var.lambda_functions.profiler.arn
        Next     = "Encoding Profile Check"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "Encoding Profile Check" = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.isCustomTemplate"
            BooleanEquals = true
            Next          = "Custom jobTemplate"
          },
          {
            Variable     = "$.encodingProfile"
            NumericEquals = 2160
            Next         = "jobTemplate 2160p"
          },
          {
            Variable     = "$.encodingProfile"
            NumericEquals = 1080
            Next         = "jobTemplate 1080p"
          },
          {
            Variable     = "$.encodingProfile"
            NumericEquals = 720
            Next         = "jobTemplate 720p"
          }
        ]
      }
      "Custom jobTemplate" = {
        Type = "Pass"
        Next = "Accelerated Transcoding Check"
      }
      "jobTemplate 2160p" = {
        Type = "Pass"
        Next = "Accelerated Transcoding Check"
      }
      "jobTemplate 1080p" = {
        Type = "Pass"
        Next = "Accelerated Transcoding Check"
      }
      "jobTemplate 720p" = {
        Type = "Pass"
        Next = "Accelerated Transcoding Check"
      }
      "Accelerated Transcoding Check" = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.acceleratedTranscoding"
            StringEquals = "ENABLED"
            Next         = "Enabled"
          },
          {
            Variable     = "$.acceleratedTranscoding"
            StringEquals = "PREFERRED"
            Next         = "Preferred"
          },
          {
            Variable     = "$.acceleratedTranscoding"
            StringEquals = "DISABLED"
            Next         = "Disabled"
          }
        ]
      }
      "Enabled" = {
        Type = "Pass"
        Next = "Frame Capture Check"
      }
      "Preferred" = {
        Type = "Pass"
        Next = "Frame Capture Check"
      }
      "Disabled" = {
        Type = "Pass"
        Next = "Frame Capture Check"
      }
      "Frame Capture Check" = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.frameCapture"
            BooleanEquals = true
            Next          = "Frame Capture"
          },
          {
            Variable      = "$.frameCapture"
            BooleanEquals = false
            Next          = "No Frame Capture"
          }
        ]
      }
      "Frame Capture" = {
        Type = "Pass"
        Next = "Encode Job Submit"
      }
      "No Frame Capture" = {
        Type = "Pass"
        Next = "Encode Job Submit"
      }
      "Encode Job Submit" = {
        Type     = "Task"
        Resource = var.lambda_functions.encode.arn
        Next     = "DynamoDB Update (Process)"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "DynamoDB Update (Process)" = {
        Type     = "Task"
        Resource = var.lambda_functions.dynamo_update.arn
        End      = true
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
    }
  })

  tags = {
    Name = "${var.stack_name}-process"
  }
}

# Publish Workflow State Machine
resource "aws_sfn_state_machine" "publish_workflow" {
  name     = "${var.stack_name}-publish"
  role_arn = aws_iam_role.step_functions_service_role.arn

  definition = jsonencode({
    StartAt = "Validate Encoding Outputs"
    States = {
      "Validate Encoding Outputs" = {
        Type     = "Task"
        Resource = var.lambda_functions.output_validate.arn
        Next     = "Archive Source Choice"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "Archive Source Choice" = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.archiveSource"
            StringEquals = "GLACIER"
            Next         = "Archive"
          },
          {
            Variable     = "$.archiveSource"
            StringEquals = "DEEP_ARCHIVE"
            Next         = "Deep Archive"
          }
        ]
        Default = "MediaPackage Choice"
      }
      "Archive" = {
        Type     = "Task"
        Resource = var.lambda_functions.archive_source.arn
        Next     = "MediaPackage Choice"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "Deep Archive" = {
        Type     = "Task"
        Resource = var.lambda_functions.archive_source.arn
        Next     = "MediaPackage Choice"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "MediaPackage Choice" = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.enableMediaPackage"
            BooleanEquals = true
            Next          = "MediaPackage Processing"
          }
        ]
        Default = "DynamoDB Update (Publish)"
      }
      "MediaPackage Processing" = jsondecode(local.enable_mediapackage ? jsonencode({
        Type     = "Task"
        Resource = var.lambda_functions.media_package_assets.arn
        Next     = "DynamoDB Update (Publish)"
        Comment  = "MediaPackage processing enabled"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }) : jsonencode({
        Type    = "Pass"
        Next    = "DynamoDB Update (Publish)"
        Comment = "MediaPackage processing skipped - MediaPackage VOD is disabled"
      }))
      "DynamoDB Update (Publish)" = {
        Type     = "Task"
        Resource = var.lambda_functions.dynamo_update.arn
        Next     = "SQS Choice"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "SQS Choice" = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.enableSqs"
            BooleanEquals = true
            Next          = "SQS Send Message"
          }
        ]
        Default = "SNS Choice (Publish)"
      }
      "SQS Send Message" = {
        Type     = "Task"
        Resource = var.lambda_functions.sqs_publish.arn
        Next     = "SNS Choice (Publish)"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "SNS Choice (Publish)" = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.enableSns"
            BooleanEquals = true
            Next          = "SNS Notification (Publish)"
          }
        ]
        Default = "Complete"
      }
      "SNS Notification (Publish)" = {
        Type     = "Task"
        Resource = var.lambda_functions.sns_notification.arn
        Next     = "Complete"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      "Complete" = {
        Type = "Pass"
        End  = true
      }
    }
  })

  tags = {
    Name = "${var.stack_name}-publish"
  }
}