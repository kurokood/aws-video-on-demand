# CloudFront module for Video on Demand

data "aws_caller_identity" "current" {}

# Cache Policy
resource "aws_cloudfront_cache_policy" "vod_cache_policy" {
  name        = "${var.stack_name}-vod-cache-policy-${substr(data.aws_caller_identity.current.account_id, -8, 8)}"
  comment     = "Cache policy for Video on Demand - ${var.stack_name}"
  default_ttl = 86400
  max_ttl     = 86400
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = false
    enable_accept_encoding_gzip   = false

    query_strings_config {
      query_string_behavior = "none"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = [
          "Origin",
          "Access-Control-Request-Method",
          "Access-Control-Request-Headers"
        ]
      }
    }

    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# Origin Access Control
resource "aws_cloudfront_origin_access_control" "vod_oac" {
  name                              = "aws-cloudfront-s3-vod-${var.stack_name}-${substr(data.aws_caller_identity.current.account_id, -8, 8)}"
  description                       = "Origin access control for Video on Demand - ${var.stack_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "vod_distribution" {
  origin {
    domain_name              = var.destination_bucket.bucket_regional_domain_name
    origin_id                = "VideoOnDemandCloudFrontToS3CloudFrontDistributionOrigin1"
    origin_access_control_id = aws_cloudfront_origin_access_control.vod_oac.id

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  http_version        = "http2"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "VideoOnDemandCloudFrontToS3CloudFrontDistributionOrigin1"
    cache_policy_id        = aws_cloudfront_cache_policy.vod_cache_policy.id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  logging_config {
    include_cookies = false
    bucket          = var.logs_bucket.bucket_domain_name
    prefix          = "cloudfront-logs/"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.stack_name}-cloudfront"
  }
}

# Update destination bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "destination_policy" {
  bucket = var.destination_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          var.destination_bucket.arn,
          "${var.destination_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = "s3:GetObject"
        Resource = "${var.destination_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.vod_distribution.arn
          }
        }
      }
    ]
  })
}

# Data source for region
data "aws_region" "current" {}