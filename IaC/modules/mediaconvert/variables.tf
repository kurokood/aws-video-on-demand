variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "source_bucket" {
  description = "Source S3 bucket object"
  type = object({
    id  = string
    arn = string
  })
}

variable "destination_bucket" {
  description = "Destination S3 bucket object"
  type = object({
    id  = string
    arn = string
  })
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "enable_media_package" {
  description = "Whether to enable MediaPackage VOD"
  type        = bool
  default     = false
}