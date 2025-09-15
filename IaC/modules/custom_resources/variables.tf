# Variables for Custom Resources Module

variable "stack_name" {
  description = "Name of the VOD stack for resource naming"
  type        = string
}

variable "admin_email" {
  description = "Email address for SNS notifications"
  type        = string
  validation {
    condition     = can(regex("^[_A-Za-z0-9-\\+]+(\\.[_A-Za-z0-9-]+)*@[A-Za-z0-9-]+(\\.[A-Za-z0-9]+)*(\\.[A-Za-z]{2,})$", var.admin_email))
    error_message = "Admin email must be a valid email address."
  }
}

variable "workflow_trigger" {
  description = "How the workflow will be triggered"
  type        = string
  default     = "VideoFile"
  validation {
    condition     = contains(["VideoFile", "MetadataFile"], var.workflow_trigger)
    error_message = "Workflow trigger must be either VideoFile or MetadataFile."
  }
}

variable "glacier" {
  description = "Archive source assets to Glacier or Glacier Deep Archive"
  type        = string
  default     = "DISABLED"
  validation {
    condition     = contains(["DISABLED", "GLACIER", "DEEP_ARCHIVE"], var.glacier)
    error_message = "Glacier must be one of: DISABLED, GLACIER, DEEP_ARCHIVE."
  }
}

variable "frame_capture" {
  description = "Enable frame capture in MediaConvert jobs"
  type        = bool
  default     = false
}

variable "enable_media_package" {
  description = "Enable MediaPackage VOD in the workflow"
  type        = bool
  default     = false
}

variable "enable_sns" {
  description = "Enable SNS notifications"
  type        = bool
  default     = true
}

variable "enable_sqs" {
  description = "Enable SQS messaging"
  type        = bool
  default     = true
}

variable "accelerated_transcoding" {
  description = "Enable accelerated transcoding in MediaConvert"
  type        = string
  default     = "PREFERRED"
  validation {
    condition     = contains(["ENABLED", "DISABLED", "PREFERRED"], var.accelerated_transcoding)
    error_message = "Accelerated transcoding must be one of: ENABLED, DISABLED, PREFERRED."
  }
}

variable "source_bucket_arn" {
  description = "ARN of the source S3 bucket"
  type        = string
}

variable "destination_bucket_arn" {
  description = "ARN of the destination S3 bucket"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  type        = string
  default     = ""
}
