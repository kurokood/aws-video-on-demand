# Media Resources Module
# Replaces custom_resources module with PowerShell script-based approach
# Creates MediaConvert templates and MediaPackage configuration using PowerShell scripts

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# MediaConvert Service Role
resource "aws_iam_role" "mediaconvert_role" {
  name = "${var.stack_name}-mediaconvert-service-role"

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
    Name       = "${var.stack_name}-mediaconvert-service-role"
    SolutionId = "SO0021"
  }
}

# MediaConvert Service Policy
resource "aws_iam_policy" "mediaconvert_policy" {
  name = "${var.stack_name}-mediaconvert-service-policy"

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
          "${var.source_bucket_arn}/*",
          "${var.destination_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = "execute-api:Invoke"
        Resource = "arn:${data.aws_partition.current.partition}:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })

  tags = {
    Name       = "${var.stack_name}-mediaconvert-service-policy"
    SolutionId = "SO0021"
  }
}

# Attach MediaConvert policy to role
resource "aws_iam_role_policy_attachment" "mediaconvert_policy_attachment" {
  role       = aws_iam_role.mediaconvert_role.name
  policy_arn = aws_iam_policy.mediaconvert_policy.arn
}

# MediaPackage VOD Service Role (if enabled)
resource "aws_iam_role" "mediapackage_vod_role" {
  count = var.enable_media_package ? 1 : 0
  name  = "${var.stack_name}-mediapackage-vod-service-role"

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
    Name       = "${var.stack_name}-mediapackage-vod-service-role"
    SolutionId = "SO0021"
  }
}

# MediaPackage VOD Service Policy
resource "aws_iam_policy" "mediapackage_vod_policy" {
  count = var.enable_media_package ? 1 : 0
  name  = "${var.stack_name}-mediapackage-vod-service-policy"

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
          var.destination_bucket_arn,
          "${var.destination_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name       = "${var.stack_name}-mediapackage-vod-service-policy"
    SolutionId = "SO0021"
  }
}

# Attach MediaPackage VOD policy to role
resource "aws_iam_role_policy_attachment" "mediapackage_vod_policy_attachment" {
  count      = var.enable_media_package ? 1 : 0
  role       = aws_iam_role.mediapackage_vod_role[0].name
  policy_arn = aws_iam_policy.mediapackage_vod_policy[0].arn
}

# Get MediaConvert endpoint
data "aws_mediaconvert_endpoints" "current" {}

# Create MediaConvert templates and MediaPackage configuration using PowerShell scripts
resource "null_resource" "deploy_media_resources" {
  triggers = {
    stack_name                 = var.stack_name
    region                    = var.aws_region
    source_bucket_arn         = var.source_bucket_arn
    destination_bucket_arn    = var.destination_bucket_arn
    enable_media_package      = var.enable_media_package
    cloudfront_distribution_id = var.cloudfront_distribution_id
    mediaconvert_role_arn     = aws_iam_role.mediaconvert_role.arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      powershell.exe -ExecutionPolicy Bypass -File "${path.module}/../../scripts/Deploy-MediaResources.ps1" `
        -StackName "${var.stack_name}" `
        -Region "${var.aws_region}" `
        -SourceBucketArn "${var.source_bucket_arn}" `
        -DestinationBucketArn "${var.destination_bucket_arn}" `
        -EnableMediaPackage:$${var.enable_media_package} `
        -CloudFrontDistributionId "${var.cloudfront_distribution_id}" `
        -MediaConvertRoleArn "${aws_iam_role.mediaconvert_role.arn}"
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      powershell.exe -ExecutionPolicy Bypass -File "${path.module}/../../scripts/Remove-MediaResources.ps1" `
        -StackName "${self.triggers.stack_name}" `
        -Region "${self.triggers.region}" `
        -EnableMediaPackage:$${self.triggers.enable_media_package}
    EOT
  }
}

# Store MediaPackage configuration details in SSM Parameter Store for reference
resource "aws_ssm_parameter" "mediapackage_group_id" {
  count = var.enable_media_package ? 1 : 0
  name  = "/${var.stack_name}/mediapackage/group-id"
  type  = "String"
  value = "${var.stack_name}-packaging-group"

  tags = {
    Name       = "${var.stack_name}-mediapackage-group-id"
    SolutionId = "SO0021"
  }
}

resource "aws_ssm_parameter" "mediapackage_domain_name" {
  count = var.enable_media_package ? 1 : 0
  name  = "/${var.stack_name}/mediapackage/domain-name"
  type  = "String"
  value = "placeholder" # This will be updated by the PowerShell script

  tags = {
    Name       = "${var.stack_name}-mediapackage-domain-name"
    SolutionId = "SO0021"
  }
}

# Store MediaConvert template names in SSM Parameter Store for reference
resource "aws_ssm_parameter" "mediaconvert_templates" {
  name  = "/${var.stack_name}/mediaconvert/templates"
  type  = "String"
  value = jsonencode({
    "2160p_qvbr" = "${var.stack_name}_Ott_2160p_Avc_Aac_16x9_qvbr_no_preset"
    "1080p_qvbr" = "${var.stack_name}_Ott_1080p_Avc_Aac_16x9_qvbr_no_preset"
    "720p_qvbr"  = "${var.stack_name}_Ott_720p_Avc_Aac_16x9_qvbr_no_preset"
    "2160p_mvod" = var.enable_media_package ? "${var.stack_name}_Ott_2160p_Avc_Aac_16x9_mvod_no_preset" : ""
    "1080p_mvod" = var.enable_media_package ? "${var.stack_name}_Ott_1080p_Avc_Aac_16x9_mvod_no_preset" : ""
    "720p_mvod"  = var.enable_media_package ? "${var.stack_name}_Ott_720p_Avc_Aac_16x9_mvod_no_preset" : ""
  })

  tags = {
    Name       = "${var.stack_name}-mediaconvert-templates"
    SolutionId = "SO0021"
  }
}
