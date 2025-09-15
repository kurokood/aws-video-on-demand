output "packaging_group_id" {
  description = "MediaPackage VOD packaging group ID (not available in current provider)"
  value       = null
}

output "hls_packaging_configuration_id" {
  description = "MediaPackage VOD HLS packaging configuration ID (not available in current provider)"
  value       = null
}

output "dash_packaging_configuration_id" {
  description = "MediaPackage VOD DASH packaging configuration ID (not available in current provider)"
  value       = null
}

output "mediapackage_vod_role_arn" {
  description = "MediaPackage VOD service role ARN"
  value       = var.enable_media_package ? aws_iam_role.mediapackage_vod_role[0].arn : null
}
