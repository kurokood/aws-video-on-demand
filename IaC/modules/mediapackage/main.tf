# MediaPackage VOD module for Video on Demand
# Note: MediaPackage VOD resources are not yet available in the AWS provider
# This module provides placeholder outputs for compatibility

# MediaPackage VOD IAM Role
resource "aws_iam_role" "mediapackage_vod_role" {
  count = var.enable_media_package ? 1 : 0
  
  name = "${var.stack_name}-mediapackage-vod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "mediapackage.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.stack_name}-mediapackage-vod-role"
  }
}

# MediaPackage VOD IAM Policy
resource "aws_iam_policy" "mediapackage_vod_policy" {
  count = var.enable_media_package ? 1 : 0
  
  name = "${var.stack_name}-mediapackage-vod-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:GetBucketRequestPayment"
        ]
        Resource = [
          var.destination_bucket.arn,
          "${var.destination_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "${var.destination_bucket.arn}/mediapackage/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mediapackage_vod_policy_attachment" {
  count = var.enable_media_package ? 1 : 0
  
  role       = aws_iam_role.mediapackage_vod_role[0].name
  policy_arn = aws_iam_policy.mediapackage_vod_policy[0].arn
}
