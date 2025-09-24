# Variables for Media Resources Module

variable "stack_name" {
  description = "Name of the stack (used for resource naming)"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "source_bucket_arn" {
  description = "ARN of the source S3 bucket"
  type        = string
}

variable "destination_bucket_arn" {
  description = "ARN of the destination S3 bucket"
  type        = string
}

variable "enable_media_package" {
  description = "Enable MediaPackage VOD"
  type        = bool
  default     = false
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  type        = string
  default     = ""
}
