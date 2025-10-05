# Outputs for Video on Demand on AWS
output "cloudfront_domain_name" {
  description = "CloudFront Distribution Domain Name"
  value       = module.cloudfront.domain_name
}