output "notification_id" {
  description = "S3 bucket notification ID"
  value       = aws_s3_bucket_notification.source_bucket_notification.id
}