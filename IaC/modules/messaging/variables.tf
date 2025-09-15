variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "admin_email" {
  description = "Admin email for notifications"
  type        = string
}

variable "enable_sns" {
  description = "Enable SNS notifications"
  type        = bool
  default     = false
}