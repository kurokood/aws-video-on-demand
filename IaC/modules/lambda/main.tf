# Lambda module for Video on Demand

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  solution_identifier = "AwsSolution/SO0021/${var.solution_version}"
  lambda_runtime      = "nodejs22.x"
  python_runtime      = "python3.13"
  lambda_timeout      = 120
}

# Create ZIP files for Lambda functions from actual source code
data "archive_file" "step_functions_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/step_functions.zip"
  source_dir  = "${path.root}/lambda_functions/step-functions"
}


data "archive_file" "input_validate_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/input_validate.zip"
  source_dir  = "${path.root}/lambda_functions/input-validate"
}

data "archive_file" "encode_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/encode.zip"
  source_dir  = "${path.root}/lambda_functions/encode"
}

data "archive_file" "mediainfo_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/mediainfo.zip"
  source_dir  = "${path.root}/lambda_functions/mediainfo"
}

data "archive_file" "profiler_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/profiler.zip"
  source_dir  = "${path.root}/lambda_functions/profiler"
}

data "archive_file" "dynamo_update_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/dynamo_update.zip"
  source_dir  = "${path.root}/lambda_functions/dynamo-update"
}

data "archive_file" "error_handler_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/error_handler.zip"
  source_dir  = "${path.root}/lambda_functions/error-handler"
}

data "archive_file" "output_validate_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/output_validate.zip"
  source_dir  = "${path.root}/lambda_functions/output-validate"
}

data "archive_file" "archive_source_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/archive_source.zip"
  source_dir  = "${path.root}/lambda_functions/archive-source"
}

data "archive_file" "sns_notification_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/sns_notification.zip"
  source_dir  = "${path.root}/lambda_functions/sns-notification"
}

data "archive_file" "sqs_publish_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/sqs_publish.zip"
  source_dir  = "${path.root}/lambda_functions/sqs-publish"
}

data "archive_file" "media_package_assets_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_zips/media_package_assets.zip"
  source_dir  = "${path.root}/lambda_functions/media-package-assets"
}


# MediaPackage Assets Lambda
resource "aws_iam_role" "media_package_assets_role" {
  count = var.enable_media_package ? 1 : 0
  name = "${var.stack_name}-media-package-assets-role"

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
}

resource "aws_iam_policy" "media_package_assets_policy" {
  count = var.enable_media_package ? 1 : 0
  name = "${var.stack_name}-media-package-assets-policy"

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
        Action = "iam:PassRole"
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.stack_name}-mediapackage-vod-role"
      },
      {
        Effect = "Allow"
        Action = [
          "mediapackage-vod:CreateAsset",
          "mediapackage-vod:TagResource",
          "mediapackage-vod:UntagResource"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.error_handler.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "media_package_assets_policy_attachment" {
  count = var.enable_media_package ? 1 : 0
  role       = aws_iam_role.media_package_assets_role[0].name
  policy_arn = aws_iam_policy.media_package_assets_policy[0].arn
}

resource "aws_lambda_function" "media_package_assets" {
  count = var.enable_media_package ? 1 : 0
  function_name = "${var.stack_name}-media-package-assets"
  role          = aws_iam_role.media_package_assets_role[0].arn
  handler       = "index.handler"
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.media_package_assets_zip.output_path
  source_code_hash = data.archive_file.media_package_assets_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER                 = local.solution_identifier
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      ErrorHandler                        = aws_lambda_function.error_handler.arn
      GroupId                             = var.mediapackage_group_id
      GroupDomainName                     = var.mediapackage_domain_name
      MediaPackageVodRole                 = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.stack_name}-mediapackage-vod-role"
    }
  }

  tags = {
    Name = "${var.stack_name}-media-package-assets"
  }
}


# Error Handler Lambda
resource "aws_iam_role" "error_handler_role" {
  name = "${var.stack_name}-error-handler-role"

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
    Name = "${var.stack_name}-error-handler-role"
  }
}

resource "aws_iam_policy" "error_handler_policy" {
  name = "${var.stack_name}-error-handler-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
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
        Effect   = "Allow"
        Action   = "dynamodb:UpdateItem"
        Resource = var.dynamodb_table.arn
      }
    ], var.sns_topic != null ? [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = var.sns_topic.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          }
        }
      }
    ] : [])
  })
}

resource "aws_iam_role_policy_attachment" "error_handler_policy_attachment" {
  role       = aws_iam_role.error_handler_role.name
  policy_arn = aws_iam_policy.error_handler_policy.arn
}

resource "aws_lambda_function" "error_handler" {
  function_name = "${var.stack_name}-error-handler"
  role          = aws_iam_role.error_handler_role.arn
  handler       = "index.handler"
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.error_handler_zip.output_path
  source_code_hash = data.archive_file.error_handler_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER                 = local.solution_identifier
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      DynamoDBTable                       = var.dynamodb_table.name
      SnsTopic                            = var.sns_topic != null ? var.sns_topic.arn : ""
      EnableSns                           = var.enable_sns ? "true" : "false"
    }
  }

  tags = {
    Name = "${var.stack_name}-error-handler"
  }
}

# Input Validate Lambda
resource "aws_iam_role" "input_validate_role" {
  name = "${var.stack_name}-input-validate-role"

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
}

resource "aws_iam_policy" "input_validate_policy" {
  name = "${var.stack_name}-input-validate-policy"

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
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${var.source_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.error_handler.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "input_validate_policy_attachment" {
  role       = aws_iam_role.input_validate_role.name
  policy_arn = aws_iam_policy.input_validate_policy.arn
}

resource "aws_lambda_function" "input_validate" {
  function_name = "${var.stack_name}-input-validate"
  role          = aws_iam_role.input_validate_role.arn
  handler       = "index.handler"
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.input_validate_zip.output_path
  source_code_hash = data.archive_file.input_validate_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER                 = local.solution_identifier
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      ErrorHandler                        = aws_lambda_function.error_handler.arn
      WorkflowName                        = var.stack_name
      Source                              = var.source_bucket.id
      Destination                         = var.destination_bucket.id
      FrameCapture                        = var.frame_capture ? "true" : "false"
      ArchiveSource                       = var.glacier
      CloudFront                          = var.cloudfront_domain
      EnableMediaPackage                  = var.enable_media_package ? "true" : "false"
      InputRotate                         = "DEGREE_0"
      EnableSns                           = var.enable_sns ? "true" : "false"
      EnableSqs                           = var.enable_sqs ? "true" : "false"
      AcceleratedTranscoding              = var.accelerated_transcoding
      # Individual resolution-specific MediaConvert templates
      MediaConvert_Template_2160p         = var.enable_media_package ? "${var.stack_name}_Ott_2160p_Avc_Aac_16x9_mvod_no_preset" : "${var.stack_name}_Ott_2160p_Avc_Aac_16x9_qvbr_no_preset"
      MediaConvert_Template_1080p         = var.enable_media_package ? "${var.stack_name}_Ott_1080p_Avc_Aac_16x9_mvod_no_preset" : "${var.stack_name}_Ott_1080p_Avc_Aac_16x9_qvbr_no_preset"
      MediaConvert_Template_720p          = var.enable_media_package ? "${var.stack_name}_Ott_720p_Avc_Aac_16x9_mvod_no_preset" : "${var.stack_name}_Ott_720p_Avc_Aac_16x9_qvbr_no_preset"
    }
  }

  tags = {
    Name = "${var.stack_name}-input-validate"
  }
}

# Step Functions Lambda
resource "aws_iam_role" "step_functions_role" {
  name = "${var.stack_name}-step-functions-role"

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
}

resource "aws_iam_policy" "step_functions_policy" {
  name = "${var.stack_name}-step-functions-policy"

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
        Action = "states:StartExecution"
        Resource = [
          "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.stack_name}-ingest",
          "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.stack_name}-process",
          "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.stack_name}-publish"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.error_handler.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_functions_policy_attachment" {
  role       = aws_iam_role.step_functions_role.name
  policy_arn = aws_iam_policy.step_functions_policy.arn
}

resource "aws_lambda_function" "step_functions" {
  function_name = "${var.stack_name}-step-functions"
  role          = aws_iam_role.step_functions_role.arn
  handler       = "index.handler"
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.step_functions_zip.output_path
  source_code_hash = data.archive_file.step_functions_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER                 = local.solution_identifier
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      IngestWorkflow                      = "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.stack_name}-ingest"
      ProcessWorkflow                     = "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.stack_name}-process"
      PublishWorkflow                     = "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.stack_name}-publish"
      ErrorHandler                        = aws_lambda_function.error_handler.arn
    }
  }

  tags = {
    Name = "${var.stack_name}-step-functions"
  }
}

# MediaInfo Lambda (Python)
resource "aws_iam_role" "mediainfo_role" {
  name = "${var.stack_name}-mediainfo-role"

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
}

resource "aws_iam_policy" "mediainfo_policy" {
  name = "${var.stack_name}-mediainfo-policy"

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
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${var.source_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.error_handler.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mediainfo_policy_attachment" {
  role       = aws_iam_role.mediainfo_role.name
  policy_arn = aws_iam_policy.mediainfo_policy.arn
}

resource "aws_lambda_function" "mediainfo" {
  function_name = "${var.stack_name}-mediainfo"
  role          = aws_iam_role.mediainfo_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = local.python_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.mediainfo_zip.output_path
  source_code_hash = data.archive_file.mediainfo_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER = local.solution_identifier
      ErrorHandler        = aws_lambda_function.error_handler.arn
    }
  }

  tags = {
    Name = "${var.stack_name}-mediainfo"
  }
}

# DynamoDB Update Lambda
resource "aws_iam_role" "dynamo_update_role" {
  name = "${var.stack_name}-dynamo-update-role"

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
}

resource "aws_iam_policy" "dynamo_update_policy" {
  name = "${var.stack_name}-dynamo-update-policy"

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
        Effect   = "Allow"
        Action   = "dynamodb:UpdateItem"
        Resource = var.dynamodb_table.arn
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.error_handler.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamo_update_policy_attachment" {
  role       = aws_iam_role.dynamo_update_role.name
  policy_arn = aws_iam_policy.dynamo_update_policy.arn
}

resource "aws_lambda_function" "dynamo_update" {
  function_name = "${var.stack_name}-dynamo"
  role          = aws_iam_role.dynamo_update_role.arn
  handler       = "index.handler"
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.dynamo_update_zip.output_path
  source_code_hash = data.archive_file.dynamo_update_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER                 = local.solution_identifier
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      ErrorHandler                        = aws_lambda_function.error_handler.arn
      DynamoDBTable                       = var.dynamodb_table.name
    }
  }

  tags = {
    Name = "${var.stack_name}-dynamo"
  }
}

# Profiler Lambda
resource "aws_iam_role" "profiler_role" {
  name = "${var.stack_name}-profiler-role"

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
}

resource "aws_iam_policy" "profiler_policy" {
  name = "${var.stack_name}-profiler-policy"

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
        Effect   = "Allow"
        Action   = "dynamodb:GetItem"
        Resource = var.dynamodb_table.arn
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.error_handler.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "profiler_policy_attachment" {
  role       = aws_iam_role.profiler_role.name
  policy_arn = aws_iam_policy.profiler_policy.arn
}

resource "aws_lambda_function" "profiler" {
  function_name = "${var.stack_name}-profiler"
  role          = aws_iam_role.profiler_role.arn
  handler       = "index.handler"
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.profiler_zip.output_path
  source_code_hash = data.archive_file.profiler_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER                 = local.solution_identifier
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      ErrorHandler                        = aws_lambda_function.error_handler.arn
      DynamoDBTable                       = var.dynamodb_table.name
      StackName                           = var.stack_name
      EnableMediaPackage                  = var.enable_media_package ? "true" : "false"
    }
  }

  tags = {
    Name = "${var.stack_name}-profiler"
  }
}

# Encode Lambda
resource "aws_iam_role" "encode_role" {
  name = "${var.stack_name}-encode-role"

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
}

resource "aws_iam_policy" "encode_policy" {
  name = "${var.stack_name}-encode-policy"

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
          "mediaconvert:CreateJob",
          "mediaconvert:GetJobTemplate",
          "mediaconvert:TagResource",
          "mediaconvert:UntagResource"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:mediaconvert:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.stack_name}-mediaconvert-role"
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.error_handler.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "encode_policy_attachment" {
  role       = aws_iam_role.encode_role.name
  policy_arn = aws_iam_policy.encode_policy.arn
}

resource "aws_lambda_function" "encode" {
  function_name = "${var.stack_name}-encode"
  role          = aws_iam_role.encode_role.arn
  handler       = "index.handler"
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.encode_zip.output_path
  source_code_hash = data.archive_file.encode_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER                 = local.solution_identifier
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      ErrorHandler                        = aws_lambda_function.error_handler.arn
      MediaConvertRole                    = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.stack_name}-mediaconvert-role"
      EndPoint                            = "https://mediaconvert.${data.aws_region.current.name}.amazonaws.com"
    }
  }

  tags = {
    Name = "${var.stack_name}-encode"
  }
}

# Output Validate Lambda
resource "aws_iam_role" "output_validate_role" {
  name = "${var.stack_name}-output-validate-role"

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
}

resource "aws_iam_policy" "output_validate_policy" {
  name = "${var.stack_name}-output-validate-policy"

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
        Effect   = "Allow"
        Action   = "dynamodb:GetItem"
        Resource = var.dynamodb_table.arn
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = var.destination_bucket.arn
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${var.destination_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.error_handler.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "output_validate_policy_attachment" {
  role       = aws_iam_role.output_validate_role.name
  policy_arn = aws_iam_policy.output_validate_policy.arn
}

resource "aws_lambda_function" "output_validate" {
  function_name = "${var.stack_name}-output-validate"
  role          = aws_iam_role.output_validate_role.arn
  handler       = "index.handler"
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.output_validate_zip.output_path
  source_code_hash = data.archive_file.output_validate_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER                 = local.solution_identifier
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      ErrorHandler                        = aws_lambda_function.error_handler.arn
      DynamoDBTable                       = var.dynamodb_table.name
      EndPoint                            = "https://mediaconvert.${data.aws_region.current.name}.amazonaws.com"
    }
  }

  tags = {
    Name = "${var.stack_name}-output-validate"
  }
}

# Archive Source Lambda
resource "aws_iam_role" "archive_source_role" {
  name = "${var.stack_name}-archive-source-role"

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
}

resource "aws_iam_policy" "archive_source_policy" {
  name = "${var.stack_name}-archive-source-policy"

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
        Effect   = "Allow"
        Action   = "s3:PutObjectTagging"
        Resource = "${var.source_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.error_handler.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "archive_source_policy_attachment" {
  role       = aws_iam_role.archive_source_role.name
  policy_arn = aws_iam_policy.archive_source_policy.arn
}

resource "aws_lambda_function" "archive_source" {
  function_name = "${var.stack_name}-archive-source"
  role          = aws_iam_role.archive_source_role.arn
  handler       = "index.handler"
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.archive_source_zip.output_path
  source_code_hash = data.archive_file.archive_source_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER                 = local.solution_identifier
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      ErrorHandler                        = aws_lambda_function.error_handler.arn
    }
  }

  tags = {
    Name = "${var.stack_name}-archive-source"
  }
}

# SNS Notification Lambda
resource "aws_iam_role" "sns_notification_role" {
  name = "${var.stack_name}-sns-notification-role"

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
}

resource "aws_iam_policy" "sns_notification_policy" {
  name = "${var.stack_name}-sns-notification-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
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
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.error_handler.arn
      }
    ], var.sns_topic != null ? [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = var.sns_topic.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          }
        }
      }
    ] : [])
  })
}

resource "aws_iam_role_policy_attachment" "sns_notification_policy_attachment" {
  role       = aws_iam_role.sns_notification_role.name
  policy_arn = aws_iam_policy.sns_notification_policy.arn
}

resource "aws_lambda_function" "sns_notification" {
  function_name = "${var.stack_name}-sns-notification"
  role          = aws_iam_role.sns_notification_role.arn
  handler       = "index.handler"
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.sns_notification_zip.output_path
  source_code_hash = data.archive_file.sns_notification_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER                 = local.solution_identifier
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      ErrorHandler                        = aws_lambda_function.error_handler.arn
      SnsTopic                            = var.sns_topic != null ? var.sns_topic.arn : ""
      EnableSns                           = var.enable_sns ? "true" : "false"
    }
  }

  tags = {
    Name = "${var.stack_name}-sns-notification"
  }
}

# SQS Publish Lambda
resource "aws_iam_role" "sqs_publish_role" {
  name = "${var.stack_name}-sqs-publish-role"

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
}

resource "aws_iam_policy" "sqs_publish_policy" {
  name = "${var.stack_name}-sqs-publish-policy"

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
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = var.sqs_queue.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.error_handler.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sqs_publish_policy_attachment" {
  role       = aws_iam_role.sqs_publish_role.name
  policy_arn = aws_iam_policy.sqs_publish_policy.arn
}

resource "aws_lambda_function" "sqs_publish" {
  function_name = "${var.stack_name}-sqs-publish"
  role          = aws_iam_role.sqs_publish_role.arn
  handler       = "index.handler"
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout

  filename         = data.archive_file.sqs_publish_zip.output_path
  source_code_hash = data.archive_file.sqs_publish_zip.output_base64sha256

  environment {
    variables = {
      SOLUTION_IDENTIFIER                 = local.solution_identifier
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      ErrorHandler                        = aws_lambda_function.error_handler.arn
      SqsQueue                            = var.sqs_queue.url
    }
  }

  tags = {
    Name = "${var.stack_name}-sqs-publish"
  }
}

# Custom Resource Lambda removed - using direct PowerShell script for template creation




