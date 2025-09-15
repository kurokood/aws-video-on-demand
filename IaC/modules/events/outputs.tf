output "encode_error_rule_arn" {
  description = "Encode error EventBridge rule ARN"
  value       = aws_cloudwatch_event_rule.encode_error_rule.arn
}

output "encode_complete_rule_arn" {
  description = "Encode complete EventBridge rule ARN"
  value       = aws_cloudwatch_event_rule.encode_complete_rule.arn
}