output "mediaconvert_role_arn" {
  description = "MediaConvert service role ARN"
  value       = aws_iam_role.mediaconvert_role.arn
}

output "mediapackage_vod_role_arn" {
  description = "MediaPackage VOD service role ARN"
  value       = aws_iam_role.mediapackage_vod_role.arn
}

# MediaConvert template name for universal adaptive bitrate streaming (iOS and Android compatible)
output "template_universal_name" {
  description = "MediaConvert template name for universal adaptive bitrate streaming supporting iOS and Android devices (CMAF for QVBR, HLS for MVOD)"
  value       = "${var.stack_name}_Ott_universal_Avc_Aac_16x9_qvbr_no_preset"
}

# Legacy outputs for backward compatibility (deprecated)
output "template_2160p_name" {
  description = "MediaConvert template name for 2160p source videos (deprecated - use template_universal_name)"
  value       = "${var.stack_name}_Ott_universal_Avc_Aac_16x9_qvbr_no_preset"
}

output "template_1080p_name" {
  description = "MediaConvert template name for 1080p source videos (deprecated - use template_universal_name)"
  value       = "${var.stack_name}_Ott_universal_Avc_Aac_16x9_qvbr_no_preset"
}

output "template_720p_name" {
  description = "MediaConvert template name for 720p source videos (deprecated - use template_universal_name)"
  value       = "${var.stack_name}_Ott_universal_Avc_Aac_16x9_qvbr_no_preset"
}