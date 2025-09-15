variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "lambda_functions" {
  description = "Map of Lambda functions"
  type = map(object({
    arn = string
  }))
}

variable "step_functions_lambda_arn" {
  description = "Step Functions Lambda ARN"
  type        = string
}

variable "enable_media_package" {
  description = "Enable MediaPackage processing"
  type        = bool
  default     = false
}