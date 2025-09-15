# Variables for Video on Demand on AWS

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "stack_name" {
  description = "Name of the stack (used for resource naming)"
  type        = string
  default     = "video-on-demand"
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
    error_message = "Workflow trigger must be either 'VideoFile' or 'MetadataFile'."
  }
}

variable "glacier" {
  description = "Archive source content to Glacier"
  type        = string
  default     = "DISABLED"
  validation {
    condition     = contains(["DISABLED", "GLACIER", "DEEP_ARCHIVE"], var.glacier)
    error_message = "Glacier must be one of: DISABLED, GLACIER, DEEP_ARCHIVE."
  }
}

variable "frame_capture" {
  description = "Enable frame capture in MediaConvert"
  type        = string
  default     = "No"
  validation {
    condition     = contains(["Yes", "No"], var.frame_capture)
    error_message = "Frame capture must be either 'Yes' or 'No'."
  }
}

variable "enable_media_package" {
  description = "Enable MediaPackage VOD"
  type        = string
  default     = "No"
  validation {
    condition     = contains(["Yes", "No"], var.enable_media_package)
    error_message = "Enable MediaPackage must be either 'Yes' or 'No'."
  }
}

variable "enable_sns" {
  description = "Enable SNS notifications"
  type        = string
  default     = "No"
  validation {
    condition     = contains(["Yes", "No"], var.enable_sns)
    error_message = "Enable SNS must be either 'Yes' or 'No'."
  }
}

variable "enable_sqs" {
  description = "Enable SQS messaging"
  type        = string
  default     = "Yes"
  validation {
    condition     = contains(["Yes", "No"], var.enable_sqs)
    error_message = "Enable SQS must be either 'Yes' or 'No'."
  }
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