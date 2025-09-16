# Outputs for Video on Demand on AWS

output "dynamodb_table_name" {
  description = "DynamoDB Table Name"
  value       = module.database.dynamodb_table_name
}

output "source_bucket_name" {
  description = "Source S3 Bucket Name"
  value       = module.storage.source_bucket_name
}

output "destination_bucket_name" {
  description = "Destination S3 Bucket Name"
  value       = module.storage.destination_bucket_name
}

output "cloudfront_domain_name" {
  description = "CloudFront Distribution Domain Name"
  value       = module.cloudfront.domain_name
}

output "sns_topic_name" {
  description = "SNS Topic Name"
  value       = local.enable_sns ? module.messaging.sns_topic_name : "SNS disabled"
}

output "sqs_queue_url" {
  description = "SQS Queue URL"
  value       = module.messaging.sqs_queue_url
}

output "sqs_queue_arn" {
  description = "SQS Queue ARN"
  value       = module.messaging.sqs_queue_arn
}

output "anonymized_metric_uuid" {
  description = "UUID for anonymized metrics"
  value       = random_uuid.solution_uuid.result
}

output "mediaconvert_templates" {
  description = "MediaConvert template names for video processing"
  value = {
    # Individual resolution-specific templates are now used instead of universal templates
    # Templates are selected dynamically based on source video resolution to prevent upscaling
    all_templates = module.custom_resources.template_names
  }
}

output "step_functions_arns" {
  description = "ARNs of the Step Functions state machines"
  value = {
    ingest  = module.step_functions.ingest_workflow_arn
    process = module.step_functions.process_workflow_arn
    publish = module.step_functions.publish_workflow_arn
  }
}

output "mediaconvert_endpoint_url" {
  description = "MediaConvert endpoint URL"
  value       = module.custom_resources.mediaconvert_endpoint_url
}

output "mediaconvert_role_arn" {
  description = "MediaConvert service role ARN"
  value       = module.custom_resources.mediaconvert_role_arn
}

output "mediapackage_group_id" {
  description = "MediaPackage VOD packaging group ID (if enabled)"
  value       = module.custom_resources.mediapackage_group_id
}

output "mediapackage_group_domain_name" {
  description = "MediaPackage VOD packaging group domain name (if enabled)"
  value       = module.custom_resources.mediapackage_group_domain_name
}

output "custom_resource_lambda_arn" {
  description = "Custom resource Lambda function ARN"
  value       = module.custom_resources.custom_resource_lambda_arn
}

output "video_upload_instructions" {
  description = "Instructions for uploading videos to trigger the workflow"
  value       = "Upload your video files (MP4, MPG, M4V, MOV, M2TS, AVI, MKV, WMV, FLV, WebM, 3GP, ASF, VOB, etc.) to: s3://${module.storage.source_bucket_name}/"
}

output "workflow_monitoring" {
  description = "Resources to monitor workflow execution"
  value = {
    step_functions_console = "https://console.aws.amazon.com/states/home?region=${var.aws_region}#/statemachines"
    cloudwatch_logs        = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups"
    mediaconvert_console   = "https://console.aws.amazon.com/mediaconvert/home?region=${var.aws_region}#/jobs"
    dynamodb_table         = "https://console.aws.amazon.com/dynamodbv2/home?region=${var.aws_region}#item-explorer?table=${module.database.dynamodb_table_name}"
    cloudformation_stack   = "https://console.aws.amazon.com/cloudformation/home?region=${var.aws_region}#/stacks/stackinfo?stackId=${module.custom_resources.cloudformation_stack_id}"
  }
}