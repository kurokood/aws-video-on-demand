# Outputs for Media Resources Module

# MediaConvert Outputs
output "mediaconvert_endpoint_url" {
  description = "MediaConvert endpoint URL"
  value       = data.aws_mediaconvert_endpoints.current.endpoints[0].url
}

output "mediaconvert_role_arn" {
  description = "MediaConvert service role ARN"
  value       = aws_iam_role.mediaconvert_role.arn
}

output "mediaconvert_templates" {
  description = "Created MediaConvert job templates"
  value       = jsondecode(aws_ssm_parameter.mediaconvert_templates.value)
}

# Template Names for different resolutions and types
output "template_2160p_qvbr" {
  description = "2160p QVBR MediaConvert job template name (standard VOD)"
  value       = "${var.stack_name}_Ott_2160p_Avc_Aac_16x9_qvbr_no_preset"
}

output "template_1080p_qvbr" {
  description = "1080p QVBR MediaConvert job template name (standard VOD)"
  value       = "${var.stack_name}_Ott_1080p_Avc_Aac_16x9_qvbr_no_preset"
}

output "template_720p_qvbr" {
  description = "720p QVBR MediaConvert job template name (standard VOD)"
  value       = "${var.stack_name}_Ott_720p_Avc_Aac_16x9_qvbr_no_preset"
}

output "template_2160p_mvod" {
  description = "2160p MVOD MediaConvert job template name (MediaPackage VOD)"
  value       = var.enable_media_package ? "${var.stack_name}_Ott_2160p_Avc_Aac_16x9_mvod_no_preset" : ""
}

output "template_1080p_mvod" {
  description = "1080p MVOD MediaConvert job template name (MediaPackage VOD)"
  value       = var.enable_media_package ? "${var.stack_name}_Ott_1080p_Avc_Aac_16x9_mvod_no_preset" : ""
}

output "template_720p_mvod" {
  description = "720p MVOD MediaConvert job template name (MediaPackage VOD)"
  value       = var.enable_media_package ? "${var.stack_name}_Ott_720p_Avc_Aac_16x9_mvod_no_preset" : ""
}

# MediaPackage VOD Outputs (conditional)
output "mediapackage_group_id" {
  description = "MediaPackage VOD packaging group ID"
  value       = var.enable_media_package ? aws_ssm_parameter.mediapackage_group_id[0].value : ""
}

output "mediapackage_group_domain_name" {
  description = "MediaPackage VOD packaging group domain name"
  value       = var.enable_media_package ? aws_ssm_parameter.mediapackage_domain_name[0].value : ""
}

output "mediapackage_vod_role_arn" {
  description = "MediaPackage VOD service role ARN"
  value       = var.enable_media_package ? aws_iam_role.mediapackage_vod_role[0].arn : ""
}

# Template name mappings for backward compatibility
output "template_names" {
  description = "Map of all template names by resolution and type"
  value = {
    "2160p_qvbr" = "${var.stack_name}_Ott_2160p_Avc_Aac_16x9_qvbr_no_preset"
    "1080p_qvbr" = "${var.stack_name}_Ott_1080p_Avc_Aac_16x9_qvbr_no_preset"
    "720p_qvbr"  = "${var.stack_name}_Ott_720p_Avc_Aac_16x9_qvbr_no_preset"
    "2160p_mvod" = var.enable_media_package ? "${var.stack_name}_Ott_2160p_Avc_Aac_16x9_mvod_no_preset" : ""
    "1080p_mvod" = var.enable_media_package ? "${var.stack_name}_Ott_1080p_Avc_Aac_16x9_mvod_no_preset" : ""
    "720p_mvod"  = var.enable_media_package ? "${var.stack_name}_Ott_720p_Avc_Aac_16x9_mvod_no_preset" : ""
  }
}
