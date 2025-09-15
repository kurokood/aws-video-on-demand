variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "error_handler_lambda" {
  description = "Error handler Lambda function ARN"
  type        = string
}

variable "step_functions_lambda" {
  description = "Step Functions Lambda function ARN"
  type        = string
}