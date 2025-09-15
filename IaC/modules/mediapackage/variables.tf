variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "enable_media_package" {
  description = "Whether to enable MediaPackage VOD"
  type        = bool
  default     = false
}

variable "destination_bucket" {
  description = "Destination S3 bucket object"
  type = object({
    id  = string
    arn = string
  })
}
