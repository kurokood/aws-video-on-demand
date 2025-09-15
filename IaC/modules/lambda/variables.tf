variable "stack_name" {
  description = "Name of the stack"
  type        = string
  default     = "vod"
}

variable "solution_version" {
  description = "Solution version"
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

variable "dynamodb_table" {
  description = "DynamoDB table object"
  type = object({
    name = string
    arn  = string
  })
}

variable "sns_topic" {
  description = "SNS topic object"
  type = object({
    arn = string
  })
}

variable "sqs_queue" {
  description = "SQS queue object"
  type = object({
    arn = string
    url = string
  })
}

variable "cloudfront_domain" {
  description = "CloudFront domain name"
  type        = string
}

variable "frame_capture" {
  description = "Enable frame capture"
  type        = bool
  default     = true
}

variable "glacier" {
  description = "Glacier archiving setting"
  type        = string
  default     = "GLACIER"
}


variable "mediaconvert_template_universal" {
  description = "Universal MediaConvert template for iOS and Android compatible output (CMAF for QVBR, HLS for MVOD)"
  type        = string
}

variable "enable_media_package" {
  description = "Enable MediaPackage"
  type        = bool
  default     = true
}

variable "enable_sns" {
  description = "Enable SNS notifications"
  type        = bool
  default     = false
}

variable "enable_sqs" {
  description = "Enable SQS messaging"
  type        = bool
  default     = true
}

variable "accelerated_transcoding" {
  description = "Accelerated transcoding setting"
  type        = string
  default     = "PREFERRED"
}

variable "mediapackage_group_id" {
  description = "MediaPackage VOD packaging group ID"
  type        = string
  default     = ""
}

variable "mediapackage_domain_name" {
  description = "MediaPackage VOD packaging group domain name"
  type        = string
  default     = ""
}