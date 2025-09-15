param(
    [string]$StackName = "vod",
    [string]$Region = "us-east-1",
    [string]$DestinationBucket = "",
    [string]$CloudFrontDomain = ""
)

Write-Host "Creating MediaPackage VOD packaging groups..."
Write-Host "Stack Name: $StackName"
Write-Host "Region: $Region"
Write-Host "Destination Bucket: $DestinationBucket"
Write-Host "CloudFront Domain: $CloudFrontDomain"

# Get the destination bucket name if not provided
if ([string]::IsNullOrEmpty($DestinationBucket)) {
    $DestinationBucket = (aws s3api list-buckets --query "Buckets[?contains(Name, '$StackName-destination')].Name" --output text --region $Region)
    if ([string]::IsNullOrEmpty($DestinationBucket)) {
        Write-Error "Could not find destination bucket for stack $StackName"
        exit 1
    }
    Write-Host "Found destination bucket: $DestinationBucket"
}

# Create Packaging Group first
Write-Host "Creating packaging group..."
$packagingGroupJson = @{
    Id = "$StackName-packaging-group"
    Tags = @{
        SolutionId = "SO0021"
        Name = "$StackName-packaging-group"
    }
} | ConvertTo-Json -Depth 10

$packagingGroupFile = [System.IO.Path]::GetTempFileName()
$packagingGroupJson | Set-Content $packagingGroupFile

try {
    aws mediapackage-vod create-packaging-group --cli-input-json file://$packagingGroupFile --region $Region --no-cli-pager
    Write-Host "Successfully created packaging group"
} catch {
    Write-Warning "Packaging group may already exist or failed to create: $_"
}

Remove-Item $packagingGroupFile

# Create HLS Packaging Configuration (Traditional HLS)
Write-Host "Creating HLS packaging configuration..."
$hlsConfigJson = @{
    Id = "$StackName-hls-packaging-config"
    PackagingGroupId = "$StackName-packaging-group"
    HlsPackage = @{
        HlsManifests = @(
            @{
                AdMarkers = "NONE"
                IncludeIframeOnlyStream = $false
                ManifestName = "index"
                ProgramDateTimeIntervalSeconds = 0
                RepeatExtXKey = $false
                StreamSelection = @{
                    MaxVideoBitsPerSecond = 2147483647
                    MinVideoBitsPerSecond = 0
                    StreamOrder = "ORIGINAL"
                }
            }
        )
        SegmentDurationSeconds = 10
        UseAudioRenditionGroup = $false
    }
    Tags = @{
        SolutionId = "SO0021"
        Format = "HLS"
    }
} | ConvertTo-Json -Depth 10

$hlsConfigFile = [System.IO.Path]::GetTempFileName()
$hlsConfigJson | Set-Content $hlsConfigFile

try {
    aws mediapackage-vod create-packaging-configuration --cli-input-json file://$hlsConfigFile --region $Region --no-cli-pager
    Write-Host "Successfully created HLS packaging configuration"
} catch {
    Write-Warning "HLS packaging configuration may already exist or failed to create: $_"
}

Remove-Item $hlsConfigFile

# Create DASH Packaging Configuration
Write-Host "Creating DASH packaging configuration..."
$dashConfigJson = @{
    Id = "$StackName-dash-packaging-config"
    PackagingGroupId = "$StackName-packaging-group"
    DashPackage = @{
        DashManifests = @(
            @{
                ManifestName = "index"
                StreamSelection = @{
                    MaxVideoBitsPerSecond = 2147483647
                    MinVideoBitsPerSecond = 0
                    StreamOrder = "ORIGINAL"
                }
            }
        )
        SegmentDurationSeconds = 10
    }
    Tags = @{
        SolutionId = "SO0021"
        Format = "DASH"
    }
} | ConvertTo-Json -Depth 10

$dashConfigFile = [System.IO.Path]::GetTempFileName()
$dashConfigJson | Set-Content $dashConfigFile

try {
    aws mediapackage-vod create-packaging-configuration --cli-input-json file://$dashConfigFile --region $Region --no-cli-pager
    Write-Host "Successfully created DASH packaging configuration"
} catch {
    Write-Warning "DASH packaging configuration may already exist or failed to create: $_"
}

Remove-Item $dashConfigFile

# Create MSS Packaging Configuration
Write-Host "Creating MSS packaging configuration..."
$mssConfigJson = @{
    Id = "$StackName-mss-packaging-config"
    PackagingGroupId = "$StackName-packaging-group"
    MssPackage = @{
        MssManifests = @(
            @{
                ManifestName = "index"
                StreamSelection = @{
                    MaxVideoBitsPerSecond = 2147483647
                    MinVideoBitsPerSecond = 0
                    StreamOrder = "ORIGINAL"
                }
            }
        )
        SegmentDurationSeconds = 10
    }
    Tags = @{
        SolutionId = "SO0021"
        Format = "MSS"
    }
} | ConvertTo-Json -Depth 10

$mssConfigFile = [System.IO.Path]::GetTempFileName()
$mssConfigJson | Set-Content $mssConfigFile

try {
    aws mediapackage-vod create-packaging-configuration --cli-input-json file://$mssConfigFile --region $Region --no-cli-pager
    Write-Host "Successfully created MSS packaging configuration"
} catch {
    Write-Warning "MSS packaging configuration may already exist or failed to create: $_"
}

Remove-Item $mssConfigFile

# Create CMAF Packaging Configuration
Write-Host "Creating CMAF packaging configuration..."
$cmafConfigJson = @{
    Id = "$StackName-cmaf-packaging-config"
    PackagingGroupId = "$StackName-packaging-group"
    CmafPackage = @{
        HlsManifests = @(
            @{
                AdMarkers = "NONE"
                IncludeIframeOnlyStream = $false
                ManifestName = "index"
                ProgramDateTimeIntervalSeconds = 0
                RepeatExtXKey = $false
                StreamSelection = @{
                    MaxVideoBitsPerSecond = 2147483647
                    MinVideoBitsPerSecond = 0
                    StreamOrder = "ORIGINAL"
                }
            }
        )
        SegmentDurationSeconds = 10
    }
    Tags = @{
        SolutionId = "SO0021"
        Format = "CMAF"
    }
} | ConvertTo-Json -Depth 10

$cmafConfigFile = [System.IO.Path]::GetTempFileName()
$cmafConfigJson | Set-Content $cmafConfigFile

try {
    aws mediapackage-vod create-packaging-configuration --cli-input-json file://$cmafConfigFile --region $Region --no-cli-pager
    Write-Host "Successfully created CMAF packaging configuration"
} catch {
    Write-Warning "CMAF packaging configuration may already exist or failed to create: $_"
}

Remove-Item $cmafConfigFile

# Note: Test asset creation removed - assets are created by the media-package-assets Lambda function during workflow execution

Write-Host "MediaPackage VOD setup completed"
Write-Host ""
Write-Host "Created resources:"
Write-Host "- Packaging Group: $StackName-packaging-group"
Write-Host "- HLS Configuration: $StackName-hls-packaging-config"
Write-Host "- DASH Configuration: $StackName-dash-packaging-config"
Write-Host "- MSS Configuration: $StackName-mss-packaging-config"
Write-Host "- CMAF Configuration: $StackName-cmaf-packaging-config"
Write-Host ""
Write-Host "Note: Individual assets will be created by the media-package-assets Lambda function during workflow execution"
