# DynamoDB module for Video on Demand

resource "aws_dynamodb_table" "vod_table" {
  name           = var.stack_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "guid"

  attribute {
    name = "guid"
    type = "S"
  }

  attribute {
    name = "srcBucket"
    type = "S"
  }

  attribute {
    name = "startTime"
    type = "S"
  }

  global_secondary_index {
    name            = "srcBucket-startTime-index"
    hash_key        = "srcBucket"
    range_key       = "startTime"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = var.stack_name
  }
}