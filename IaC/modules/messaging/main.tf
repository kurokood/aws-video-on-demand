# Messaging module - SNS and SQS for Video on Demand

# SNS Topic (only if SNS is enabled)
resource "aws_sns_topic" "vod_notifications" {
  count = var.enable_sns ? 1 : 0
  
  name              = "${var.stack_name}-Notifications"
  display_name      = "${var.stack_name}-Notifications"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name = "${var.stack_name}-notifications"
  }
}

# SNS Subscription (only if SNS is enabled)
resource "aws_sns_topic_subscription" "email_notification" {
  count = var.enable_sns ? 1 : 0
  
  topic_arn = aws_sns_topic.vod_notifications[0].arn
  protocol  = "email"
  endpoint  = var.admin_email
}

# SQS Dead Letter Queue
resource "aws_sqs_queue" "vod_dlq" {
  name                       = "${var.stack_name}-dlq"
  visibility_timeout_seconds = 120
  kms_data_key_reuse_period_seconds = 300
  kms_master_key_id         = "alias/aws/sqs"

  tags = {
    Name = "${var.stack_name}-dlq"
  }
}

resource "aws_sqs_queue_policy" "vod_dlq_policy" {
  queue_url = aws_sqs_queue.vod_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Principal = "*"
        Action = "sqs:*"
        Resource = aws_sqs_queue.vod_dlq.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# SQS Main Queue
resource "aws_sqs_queue" "vod_queue" {
  name                       = var.stack_name
  visibility_timeout_seconds = 120
  kms_data_key_reuse_period_seconds = 300
  kms_master_key_id         = "alias/aws/sqs"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.vod_dlq.arn
    maxReceiveCount     = 1
  })

  tags = {
    Name = var.stack_name
  }
}

resource "aws_sqs_queue_policy" "vod_queue_policy" {
  queue_url = aws_sqs_queue.vod_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Principal = "*"
        Action = "sqs:*"
        Resource = aws_sqs_queue.vod_queue.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}