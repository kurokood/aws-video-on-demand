variable "source_bucket_id" {
  description = "Source S3 bucket ID"
  type        = string
}

variable "source_bucket_arn" {
  description = "Source S3 bucket ARN"
  type        = string
}

variable "step_functions_lambda_arn" {
  description = "Step Functions Lambda ARN"
  type        = string
}

variable "workflow_trigger" {
  description = "Workflow trigger type"
  type        = string
}