output "sns_topic" {
  description = "SNS topic"
  value       = var.enable_sns ? aws_sns_topic.vod_notifications[0] : null
}

output "sns_topic_name" {
  description = "SNS topic name"
  value       = var.enable_sns ? aws_sns_topic.vod_notifications[0].name : null
}

output "sns_topic_arn" {
  description = "SNS topic ARN"
  value       = var.enable_sns ? aws_sns_topic.vod_notifications[0].arn : null
}

output "sqs_queue" {
  description = "SQS queue"
  value       = aws_sqs_queue.vod_queue
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.vod_queue.url
}

output "sqs_queue_arn" {
  description = "SQS queue ARN"
  value       = aws_sqs_queue.vod_queue.arn
}

output "sqs_dlq_arn" {
  description = "SQS DLQ ARN"
  value       = aws_sqs_queue.vod_dlq.arn
}