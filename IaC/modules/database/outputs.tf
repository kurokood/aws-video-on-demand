output "dynamodb_table" {
  description = "DynamoDB table"
  value       = aws_dynamodb_table.vod_table
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.vod_table.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.vod_table.arn
}