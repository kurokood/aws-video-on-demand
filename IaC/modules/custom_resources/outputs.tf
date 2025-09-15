# Outputs for Custom Resources Module

# CloudFormation Stack Outputs
output "cloudformation_stack_id" {
  description = "CloudFormation stack ID for custom resources"
  value       = aws_cloudformation_stack.vod_custom_resources.id
}

output "cloudformation_stack_name" {
  description = "CloudFormation stack name for custom resources"
  value       = aws_cloudformation_stack.vod_custom_resources.name
}

# MediaConvert Outputs
output "mediaconvert_endpoint_url" {
  description = "MediaConvert endpoint URL"
  value       = aws_cloudformation_stack.vod_custom_resources.outputs["MediaConvertEndpointUrl"]
}

output "mediaconvert_role_arn" {
  description = "MediaConvert service role ARN"
  value       = aws_iam_role.mediaconvert_role.arn
}

output "mediaconvert_templates" {
  description = "Created MediaConvert job templates"
  value       = try(aws_cloudformation_stack.vod_custom_resources.outputs["MediaConvertTemplates"], "")
}

# Template Names for different resolutions and types

output "template_universal_qvbr" {
  description = "Universal CMAF QVBR MediaConvert job template name (standard VOD)"
  value       = "${var.stack_name}_Ott_universal_Avc_Aac_16x9_qvbr_no_preset"
}

output "template_universal_mvod" {
  description = "Universal HLS MVOD MediaConvert job template name (MediaPackage VOD)"
  value       = var.enable_media_package ? "${var.stack_name}_Ott_universal_Avc_Aac_16x9_mvod_no_preset" : ""
}

# MediaPackage VOD Outputs (conditional)
output "mediapackage_group_id" {
  description = "MediaPackage VOD packaging group ID"
  value       = var.enable_media_package ? try(aws_cloudformation_stack.vod_custom_resources.outputs["MediaPackageGroupId"], "") : ""
}

output "mediapackage_group_domain_name" {
  description = "MediaPackage VOD packaging group domain name"
  value       = var.enable_media_package ? try(aws_cloudformation_stack.vod_custom_resources.outputs["MediaPackageGroupDomainName"], "") : ""
}

output "mediapackage_vod_role_arn" {
  description = "MediaPackage VOD service role ARN"
  value       = var.enable_media_package ? aws_iam_role.mediapackage_vod_role[0].arn : ""
}

output "mediapackage_packaging_configurations" {
  description = "Created MediaPackage packaging configurations"
  value       = var.enable_media_package ? try(aws_cloudformation_stack.vod_custom_resources.outputs["MediaPackagePackagingConfigurations"], "") : ""
}

# Lambda Function Outputs
output "custom_resource_lambda_arn" {
  description = "Custom resource Lambda function ARN"
  value       = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.stack_name}-custom-resource"
}

output "custom_resource_lambda_name" {
  description = "Custom resource Lambda function name"
  value       = "${var.stack_name}-custom-resource"
}

# Solution UUID
output "solution_uuid" {
  description = "Solution UUID for anonymized metrics"
  value       = try(aws_cloudformation_stack.vod_custom_resources.outputs["SolutionUUID"], "")
}

# Template name mappings for backward compatibility
output "template_names" {
  description = "Map of all template names by resolution and type"
  value = {
    "2160p_qvbr"       = "${var.stack_name}_Ott_2160p_Avc_Aac_16x9_qvbr_no_preset"
    "1080p_qvbr"       = "${var.stack_name}_Ott_1080p_Avc_Aac_16x9_qvbr_no_preset"
    "720p_qvbr"        = "${var.stack_name}_Ott_720p_Avc_Aac_16x9_qvbr_no_preset"
    "2160p_mvod"       = var.enable_media_package ? "${var.stack_name}_Ott_2160p_Avc_Aac_16x9_mvod_no_preset" : ""
    "1080p_mvod"       = var.enable_media_package ? "${var.stack_name}_Ott_1080p_Avc_Aac_16x9_mvod_no_preset" : ""
    "720p_mvod"        = var.enable_media_package ? "${var.stack_name}_Ott_720p_Avc_Aac_16x9_mvod_no_preset" : ""
    "universal_qvbr"   = "${var.stack_name}_Ott_universal_Avc_Aac_16x9_qvbr_no_preset"
    "universal_mvod"   = var.enable_media_package ? "${var.stack_name}_Ott_universal_Avc_Aac_16x9_mvod_no_preset" : ""
  }
}
