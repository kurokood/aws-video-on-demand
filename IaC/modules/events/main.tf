# EventBridge rules for Video on Demand

# MediaConvert Error Event Rule
resource "aws_cloudwatch_event_rule" "encode_error_rule" {
  name        = "${var.stack_name}-EncodeError"
  description = "MediaConvert Error event rule"

  event_pattern = jsonencode({
    source = ["aws.mediaconvert"]
    detail = {
      status = ["ERROR"]
      userMetadata = {
        workflow = [var.stack_name]
      }
    }
  })

  tags = {
    Name = "${var.stack_name}-encode-error-rule"
  }
}

resource "aws_cloudwatch_event_target" "encode_error_target" {
  rule      = aws_cloudwatch_event_rule.encode_error_rule.name
  target_id = "Target0"
  arn       = var.error_handler_lambda
}

resource "aws_lambda_permission" "allow_eventbridge_error" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.error_handler_lambda
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.encode_error_rule.arn
}

# MediaConvert Complete Event Rule
resource "aws_cloudwatch_event_rule" "encode_complete_rule" {
  name        = "${var.stack_name}-EncodeComplete"
  description = "MediaConvert Completed event rule"

  event_pattern = jsonencode({
    source = ["aws.mediaconvert"]
    detail = {
      status = ["COMPLETE"]
      userMetadata = {
        workflow = [var.stack_name]
      }
    }
  })

  tags = {
    Name = "${var.stack_name}-encode-complete-rule"
  }
}

resource "aws_cloudwatch_event_target" "encode_complete_target" {
  rule      = aws_cloudwatch_event_rule.encode_complete_rule.name
  target_id = "Target0"
  arn       = var.step_functions_lambda
}

resource "aws_lambda_permission" "allow_eventbridge_complete" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.step_functions_lambda
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.encode_complete_rule.arn
}