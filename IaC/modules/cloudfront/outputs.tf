output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.vod_distribution.id
}

output "domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.vod_distribution.domain_name
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.vod_distribution.arn
}