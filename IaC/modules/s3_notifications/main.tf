# S3 Event Notifications module for Video on Demand

# Lambda permission for S3 to invoke Step Functions Lambda
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = var.step_functions_lambda_arn
  principal     = "s3.amazonaws.com"
  source_arn    = var.source_bucket_arn
}

# S3 bucket notification configuration
resource "aws_s3_bucket_notification" "source_bucket_notification" {
  bucket = var.source_bucket_id

  lambda_function {
    lambda_function_arn = var.step_functions_lambda_arn
    events              = ["s3:ObjectCreated:*"]
    
    # Filter based on workflow trigger type
    filter_suffix = var.workflow_trigger == "VideoFile" ? ".mp4" : ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}