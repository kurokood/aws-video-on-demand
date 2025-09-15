variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "destination_bucket" {
  description = "Destination S3 bucket object"
  type = object({
    id                          = string
    arn                         = string
    bucket_regional_domain_name = string
  })
}

variable "logs_bucket" {
  description = "Logs S3 bucket object"
  type = object({
    bucket_domain_name = string
  })
}