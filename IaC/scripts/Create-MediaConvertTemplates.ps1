# Create-MediaConvertTemplates.ps1
# PowerShell script to create MediaConvert job templates
# Replaces CloudFormation custom resource functionality

param(
    [Parameter(Mandatory=$true)]
    [string]$StackName,
    
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$true)]
    [string]$SourceBucketArn,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationBucketArn,
    
    [Parameter(Mandatory=$false)]
    [bool]$EnableMediaPackage = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$MediaConvertRoleArn = ""
)

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Initialize AWS SDK
try {
    Import-Module AWSPowerShell -ErrorAction Stop
} catch {
    Write-Error "AWS PowerShell module not found. Please install it using: Install-Module -Name AWSPowerShell"
    exit 1
}

# Get MediaConvert endpoint
Write-Host "Getting MediaConvert endpoint..."
try {
    $endpoints = Get-MCJobTemplates -MaxResults 1
    $endpoint = $endpoints[0].Endpoint
    Write-Host "MediaConvert endpoint: $endpoint"
} catch {
    Write-Error "Failed to get MediaConvert endpoint: $_"
    exit 1
}

# Set MediaConvert endpoint
$env:AWS_MEDIACONVERT_ENDPOINT = $endpoint

# Define template configurations based on MediaPackage setting
$templateConfigs = @()

if ($EnableMediaPackage) {
    # When MediaPackage is enabled, create only MVOD templates
    $templateConfigs = @(
        @{
            Name = "${StackName}_Ott_2160p_Avc_Aac_16x9_mvod_no_preset"
            Description = "2160p MVOD template for MediaPackage VOD"
            Resolution = "2160p"
            Type = "mvod"
        },
        @{
            Name = "${StackName}_Ott_1080p_Avc_Aac_16x9_mvod_no_preset"
            Description = "1080p MVOD template for MediaPackage VOD"
            Resolution = "1080p"
            Type = "mvod"
        },
        @{
            Name = "${StackName}_Ott_720p_Avc_Aac_16x9_mvod_no_preset"
            Description = "720p MVOD template for MediaPackage VOD"
            Resolution = "720p"
            Type = "mvod"
        }
    )
} else {
    # When MediaPackage is disabled, create only QVBR templates
    $templateConfigs = @(
        @{
            Name = "${StackName}_Ott_2160p_Avc_Aac_16x9_qvbr_no_preset"
            Description = "2160p QVBR template for standard VOD"
            Resolution = "2160p"
            Type = "qvbr"
        },
        @{
            Name = "${StackName}_Ott_1080p_Avc_Aac_16x9_qvbr_no_preset"
            Description = "1080p QVBR template for standard VOD"
            Resolution = "1080p"
            Type = "qvbr"
        },
        @{
            Name = "${StackName}_Ott_720p_Avc_Aac_16x9_qvbr_no_preset"
            Description = "720p QVBR template for standard VOD"
            Resolution = "720p"
            Type = "qvbr"
        }
    )
}

# Create templates
$createdTemplates = @()

foreach ($config in $templateConfigs) {
    try {
        Write-Host "Creating template: $($config.Name)"
        
        New-MCJobTemplate -Name $config.Name -Description $config.Description -Category "VOD" -Tags @{
            "SolutionId" = "SO0021"
            "StackName" = $StackName
            "TemplateType" = $config.Type
            "Resolution" = $config.Resolution
        } -Settings (Get-JobTemplateSettings -Resolution $config.Resolution -IsMVOD ($config.Type -eq "mvod") -DestinationBucket $DestinationBucketArn) | Out-Null
        
        $createdTemplates += $config.Name
        Write-Host "Successfully created template: $($config.Name)"
    } catch {
        if ($_.Exception.Message -like "*ConflictException*") {
            Write-Warning "Template $($config.Name) already exists"
            $createdTemplates += $config.Name
        } else {
            Write-Error "Error creating template $($config.Name): $_"
            throw
        }
    }
}

Write-Host "Created templates: $($createdTemplates -join ', ')"

# Function to generate job template settings
function Get-JobTemplateSettings {
    param(
        [string]$Resolution,
        [bool]$IsMVOD,
        [string]$DestinationBucket
    )
    
    # Define ABR ladders for each source resolution (no upscaling)
    $abrLadders = @{
        '2160p' = @(
            @{ height = 2160; width = 3840; bitrate = 15000000; quality = 9; name = "2160p" },
            @{ height = 1080; width = 1920; bitrate = 8500000; quality = 8; name = "1080p" },
            @{ height = 720; width = 1280; bitrate = 6000000; quality = 8; name = "720p" },
            @{ height = 480; width = 854; bitrate = 3000000; quality = 7; name = "480p" },
            @{ height = 360; width = 640; bitrate = 1500000; quality = 7; name = "360p" }
        )
        '1080p' = @(
            @{ height = 1080; width = 1920; bitrate = 8500000; quality = 8; name = "1080p" },
            @{ height = 720; width = 1280; bitrate = 6000000; quality = 8; name = "720p" },
            @{ height = 480; width = 854; bitrate = 3000000; quality = 7; name = "480p" },
            @{ height = 360; width = 640; bitrate = 1500000; quality = 7; name = "360p" }
        )
        '720p' = @(
            @{ height = 720; width = 1280; bitrate = 6000000; quality = 8; name = "720p" },
            @{ height = 480; width = 854; bitrate = 3000000; quality = 7; name = "480p" },
            @{ height = 360; width = 640; bitrate = 1500000; quality = 7; name = "360p" }
        )
    }
    
    $ladder = $abrLadders[$Resolution]
    if (-not $ladder) {
        throw "Unsupported resolution: $Resolution"
    }
    
    # Generate output groups based on template type
    $outputGroups = @()
    
    if ($IsMVOD) {
        # MediaPackage VOD - use HLS with segments (not CMAF)
        $outputGroup = @{
            Name = "$Resolution HLS Output Group"
            OutputGroupSettings = @{
                Type = "HLS_GROUP_SETTINGS"
                HlsGroupSettings = @{
                    Destination = "s3://$DestinationBucket/$($Resolution.ToLower())/hls/"
                    SegmentLength = 6
                    SegmentControl = "SEGMENTED_FILES"
                    StreamInfResolution = "INCLUDE"
                    WriteSegmentTimelineInRepresentation = "ENABLED"
                }
            }
            Outputs = @()
        }
        
        # Add video outputs
        foreach ($tier in $ladder) {
            $outputGroup.Outputs += @{
                NameModifier = "_$($tier.name)_video"
                VideoDescription = @{
                    Width = $tier.width
                    Height = $tier.height
                    ScalingBehavior = "DEFAULT"
                    TimecodeInsertion = "DISABLED"
                    AntiAlias = "ENABLED"
                    Sharpness = 50
                    CodecSettings = @{
                        Codec = "H_264"
                        H264Settings = @{
                            InterlaceMode = "PROGRESSIVE"
                            NumberReferenceFrames = 3
                            Syntax = "DEFAULT"
                            Softness = 0
                            GopClosedCadence = 1
                            GopSize = 60
                            Slices = 1
                            GopBReference = "DISABLED"
                            SlowPal = "DISABLED"
                            SpatialAdaptiveQuantization = "ENABLED"
                            TemporalAdaptiveQuantization = "ENABLED"
                            FlickerAdaptiveQuantization = "DISABLED"
                            EntropyEncoding = "CABAC"
                            FramerateControl = "INITIALIZE_FROM_SOURCE"
                            RateControlMode = "QVBR"
                            QvbrSettings = @{
                                QvbrQualityLevel = $tier.quality
                                MaxAverageBitrate = $tier.bitrate
                            }
                            MaxBitrate = $tier.bitrate
                            CodecProfile = "HIGH"
                            Telecine = "NONE"
                            MinIInterval = 0
                            AdaptiveQuantization = "HIGH"
                            CodecLevel = "AUTO"
                            FieldEncoding = "PAFF"
                            SceneChangeDetect = "ENABLED"
                            QualityTuningLevel = "MULTI_PASS_HQ"
                            FramerateConversionAlgorithm = "DUPLICATE_DROP"
                            UnregisteredSeiTimecode = "DISABLED"
                            GopSizeUnits = "FRAMES"
                            ParControl = "INITIALIZE_FROM_SOURCE"
                            NumberBFramesBetweenReferenceFrames = 2
                            RepeatPps = "DISABLED"
                            DynamicSubGop = "STATIC"
                        }
                    }
                    AfdSignaling = "NONE"
                    DropFrameTimecode = "ENABLED"
                    RespondToAfd = "NONE"
                    ColorMetadata = "INSERT"
                }
                ContainerSettings = @{
                    Container = "M3U8"
                    M3u8Settings = @{}
                }
            }
        }
        
        # Add audio output
        $outputGroup.Outputs += @{
            NameModifier = "_audio"
            AudioDescriptions = @(
                @{
                    AudioTypeControl = "FOLLOW_INPUT"
                    AudioSourceName = "Audio Selector 1"
                    CodecSettings = @{
                        Codec = "AAC"
                        AacSettings = @{
                            AudioDescriptionBroadcasterMix = "NORMAL"
                            Bitrate = 128000
                            RateControlMode = "CBR"
                            CodecProfile = "LC"
                            CodingMode = "CODING_MODE_2_0"
                            RawFormat = "NONE"
                            SampleRate = 48000
                            Specification = "MPEG4"
                        }
                    }
                    LanguageCodeControl = "FOLLOW_INPUT"
                    AudioType = 0
                }
            )
            ContainerSettings = @{
                Container = "M3U8"
                M3u8Settings = @{}
            }
        }
        
        $outputGroups += $outputGroup
    } else {
        # Standard VOD - use both HLS and DASH manifests with CMAF segments
        $outputGroup = @{
            Name = "$Resolution CMAF Output Group"
            OutputGroupSettings = @{
                Type = "CMAF_GROUP_SETTINGS"
                CmafGroupSettings = @{
                    Destination = "s3://$DestinationBucket/$($Resolution.ToLower())/cmaf/"
                    SegmentLength = 6
                    FragmentLength = 6
                    SegmentControl = "SEGMENTED_FILES"
                    WriteDashManifest = "ENABLED"
                    WriteHlsManifest = "ENABLED"
                    StreamInfResolution = "INCLUDE"
                    WriteSegmentTimelineInRepresentation = "ENABLED"
                }
            }
            Outputs = @()
        }
        
        # Add video outputs
        foreach ($tier in $ladder) {
            $outputGroup.Outputs += @{
                NameModifier = "_$($tier.name)_video"
                VideoDescription = @{
                    Width = $tier.width
                    Height = $tier.height
                    ScalingBehavior = "DEFAULT"
                    TimecodeInsertion = "DISABLED"
                    AntiAlias = "ENABLED"
                    Sharpness = 50
                    CodecSettings = @{
                        Codec = "H_264"
                        H264Settings = @{
                            InterlaceMode = "PROGRESSIVE"
                            NumberReferenceFrames = 3
                            Syntax = "DEFAULT"
                            Softness = 0
                            GopClosedCadence = 1
                            GopSize = 60
                            Slices = 1
                            GopBReference = "DISABLED"
                            SlowPal = "DISABLED"
                            SpatialAdaptiveQuantization = "ENABLED"
                            TemporalAdaptiveQuantization = "ENABLED"
                            FlickerAdaptiveQuantization = "DISABLED"
                            EntropyEncoding = "CABAC"
                            FramerateControl = "INITIALIZE_FROM_SOURCE"
                            RateControlMode = "QVBR"
                            QvbrSettings = @{
                                QvbrQualityLevel = $tier.quality
                                MaxAverageBitrate = $tier.bitrate
                            }
                            MaxBitrate = $tier.bitrate
                            CodecProfile = "HIGH"
                            Telecine = "NONE"
                            MinIInterval = 0
                            AdaptiveQuantization = "HIGH"
                            CodecLevel = "AUTO"
                            FieldEncoding = "PAFF"
                            SceneChangeDetect = "ENABLED"
                            QualityTuningLevel = "MULTI_PASS_HQ"
                            FramerateConversionAlgorithm = "DUPLICATE_DROP"
                            UnregisteredSeiTimecode = "DISABLED"
                            GopSizeUnits = "FRAMES"
                            ParControl = "INITIALIZE_FROM_SOURCE"
                            NumberBFramesBetweenReferenceFrames = 2
                            RepeatPps = "DISABLED"
                            DynamicSubGop = "STATIC"
                        }
                    }
                    AfdSignaling = "NONE"
                    DropFrameTimecode = "ENABLED"
                    RespondToAfd = "NONE"
                    ColorMetadata = "INSERT"
                }
                ContainerSettings = @{
                    Container = "CMFC"
                    CmfcSettings = @{}
                }
            }
        }
        
        # Add audio output
        $outputGroup.Outputs += @{
            NameModifier = "_audio"
            AudioDescriptions = @(
                @{
                    AudioTypeControl = "FOLLOW_INPUT"
                    AudioSourceName = "Audio Selector 1"
                    CodecSettings = @{
                        Codec = "AAC"
                        AacSettings = @{
                            AudioDescriptionBroadcasterMix = "NORMAL"
                            Bitrate = 128000
                            RateControlMode = "CBR"
                            CodecProfile = "LC"
                            CodingMode = "CODING_MODE_2_0"
                            RawFormat = "NONE"
                            SampleRate = 48000
                            Specification = "MPEG4"
                        }
                    }
                    LanguageCodeControl = "FOLLOW_INPUT"
                    AudioType = 0
                }
            )
            ContainerSettings = @{
                Container = "CMFC"
                CmfcSettings = @{}
            }
        }
        
        $outputGroups += $outputGroup
    }
    
    return @{
        Inputs = @(
            @{
                AudioSelectors = @{
                    "Audio Selector 1" = @{
                        DefaultSelection = "DEFAULT"
                        ProgramSelection = 1
                    }
                }
                VideoSelector = @{
                    Rotate = "DEGREE_0"
                }
                TimecodeSource = "EMBEDDED"
            }
        )
        TimecodeConfig = @{
            Source = "EMBEDDED"
        }
        OutputGroups = $outputGroups
    }
}

Write-Host "MediaConvert template creation completed successfully!"
