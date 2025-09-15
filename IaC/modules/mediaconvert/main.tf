# MediaConvert module for Video on Demand

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# MediaConvert Service Role
resource "aws_iam_role" "mediaconvert_role" {
  name = "${var.stack_name}-mediaconvert-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.stack_name}-mediaconvert-role"
  }
}

resource "aws_iam_policy" "mediaconvert_policy" {
  name = "${var.stack_name}-mediaconvert-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${var.source_bucket.arn}/*",
          "${var.destination_bucket.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "execute-api:Invoke"
        Resource = "arn:${data.aws_partition.current.partition}:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mediaconvert_policy_attachment" {
  role       = aws_iam_role.mediaconvert_role.name
  policy_arn = aws_iam_policy.mediaconvert_policy.arn
}

# MediaPackage VOD Role (if MediaPackage is enabled)
resource "aws_iam_role" "mediapackage_vod_role" {
  name = "${var.stack_name}-mediaconvert-mediapackage-vod-role"

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

resource "aws_iam_policy" "mediapackage_vod_policy" {
  name = "${var.stack_name}-mediaconvert-mediapackage-vod-policy"

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
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mediapackage_vod_policy_attachment" {
  role       = aws_iam_role.mediapackage_vod_role.name
  policy_arn = aws_iam_policy.mediapackage_vod_policy.arn
}

# MediaConvert Job Templates are managed by the main configuration
# Template creation is handled by null_resource.mediaconvert_templates_direct in main.tf
