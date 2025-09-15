output "logs_bucket" {
  description = "Logs S3 bucket"
  value       = aws_s3_bucket.logs
}

output "source_bucket" {
  description = "Source S3 bucket"
  value       = aws_s3_bucket.source
}

output "destination_bucket" {
  description = "Destination S3 bucket"
  value       = aws_s3_bucket.destination
}

output "source_bucket_name" {
  description = "Source S3 bucket name"
  value       = aws_s3_bucket.source.id
}

output "destination_bucket_name" {
  description = "Destination S3 bucket name"
  value       = aws_s3_bucket.destination.id
}