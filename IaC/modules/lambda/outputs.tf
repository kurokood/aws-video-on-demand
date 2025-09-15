output "lambda_functions" {
  description = "Map of Lambda functions"
  value = {
    error_handler         = aws_lambda_function.error_handler
    input_validate        = aws_lambda_function.input_validate
    step_functions        = aws_lambda_function.step_functions
    mediainfo            = aws_lambda_function.mediainfo
    dynamo_update        = aws_lambda_function.dynamo_update
    profiler             = aws_lambda_function.profiler
    encode               = aws_lambda_function.encode
    output_validate      = aws_lambda_function.output_validate
    archive_source       = aws_lambda_function.archive_source
    sns_notification     = aws_lambda_function.sns_notification
    sqs_publish          = aws_lambda_function.sqs_publish
    media_package_assets = var.enable_media_package ? aws_lambda_function.media_package_assets[0] : null
  }
}

output "error_handler_lambda_arn" {
  description = "Error handler Lambda ARN"
  value       = aws_lambda_function.error_handler.arn
}

output "step_functions_lambda_arn" {
  description = "Step Functions Lambda ARN"
  value       = aws_lambda_function.step_functions.arn
}

output "input_validate_lambda_arn" {
  description = "Input Validate Lambda ARN"
  value       = aws_lambda_function.input_validate.arn
}

output "mediainfo_lambda_arn" {
  description = "MediaInfo Lambda ARN"
  value       = aws_lambda_function.mediainfo.arn
}

output "dynamo_update_lambda_arn" {
  description = "DynamoDB Update Lambda ARN"
  value       = aws_lambda_function.dynamo_update.arn
}

output "profiler_lambda_arn" {
  description = "Profiler Lambda ARN"
  value       = aws_lambda_function.profiler.arn
}

output "encode_lambda_arn" {
  description = "Encode Lambda ARN"
  value       = aws_lambda_function.encode.arn
}

output "output_validate_lambda_arn" {
  description = "Output Validate Lambda ARN"
  value       = aws_lambda_function.output_validate.arn
}

output "archive_source_lambda_arn" {
  description = "Archive Source Lambda ARN"
  value       = aws_lambda_function.archive_source.arn
}

output "sns_notification_lambda_arn" {
  description = "SNS Notification Lambda ARN"
  value       = aws_lambda_function.sns_notification.arn
}

output "sqs_publish_lambda_arn" {
  description = "SQS Publish Lambda ARN"
  value       = aws_lambda_function.sqs_publish.arn
}

output "media_package_assets_lambda_arn" {
  description = "MediaPackage Assets Lambda ARN"
  value       = var.enable_media_package ? aws_lambda_function.media_package_assets[0].arn : null
}

