const aws = require('aws-sdk');
const https = require('https');
const url = require('url');

// Initialize AWS services
const mediaconvert = new aws.MediaConvert();
const mediapackageVod = new aws.MediaPackageVod();
const cloudfront = new aws.CloudFront();
const s3 = new aws.S3();

/**
 * Custom Resource Lambda Function for MediaConvert and MediaPackage
 * Based on Video on Demand on AWS Solution
 */
exports.handler = async (event, context) => {
    console.log('Received event:', JSON.stringify(event, null, 2));
    
    const responseData = {};
    let responseStatus = 'SUCCESS';
    
    try {
        const requestType = event.RequestType;
        const resourceType = event.ResourceProperties.Resource;
        
        switch (resourceType) {
            case 'EndPoint':
                if (requestType === 'Create' || requestType === 'Update') {
                    responseData.EndpointUrl = await getMediaConvertEndpoint();
                }
                break;
                
            case 'MediaConvertTemplates':
                if (requestType === 'Create' || requestType === 'Update') {
                    await handleMediaConvertTemplates(event.ResourceProperties, responseData);
                } else if (requestType === 'Delete') {
                    await deleteMediaConvertTemplates(event.ResourceProperties);
                }
                break;
                
            case 'MediaPackageVod':
                if (requestType === 'Create' || requestType === 'Update') {
                    await handleMediaPackageVod(event.ResourceProperties, responseData);
                } else if (requestType === 'Delete') {
                    await deleteMediaPackageVod(event.ResourceProperties);
                }
                break;
                
            case 'S3Notification':
                if (requestType === 'Create' || requestType === 'Update') {
                    await handleS3Notification(event.ResourceProperties);
                } else if (requestType === 'Delete') {
                    await deleteS3Notification(event.ResourceProperties);
                }
                break;
                
            case 'UUID':
                responseData.UUID = generateUUID();
                break;
                
            case 'AnonymizedMetric':
                if (requestType === 'Create') {
                    await sendAnonymizedMetric(event.ResourceProperties);
                }
                break;
                
            default:
                throw new Error(`Unknown resource type: ${resourceType}`);
        }
        
    } catch (error) {
        console.error('Error:', error);
        responseStatus = 'FAILED';
        responseData.Error = error.message;
    }
    
    await sendResponse(event, context, responseStatus, responseData);
};

/**
 * Get MediaConvert endpoint URL
 */
async function getMediaConvertEndpoint() {
    const params = {
        MaxResults: 1
    };
    
    const result = await mediaconvert.describeEndpoints(params).promise();
    return result.Endpoints[0].Url;
}

/**
 * Handle MediaConvert template creation
 */
async function handleMediaConvertTemplates(properties, responseData) {
    const stackName = properties.StackName;
    const enableMediaPackage = properties.EnableMediaPackage === 'true';
    const enableNewTemplates = properties.EnableNewTemplates === 'Yes';
    const endpoint = properties.EndPoint;
    
    // Set custom endpoint for MediaConvert
    mediaconvert.endpoint = endpoint;
    
    // Define template configurations - only universal templates with adaptive bitrate
    const templateConfigs = [
        {
            name: `${stackName}_Ott_universal_Avc_Aac_16x9_qvbr_no_preset`,
            description: 'Universal CMAF adaptive bitrate template for iOS and Android devices (standard VOD)',
            resolution: 'universal',
            type: 'universal_qvbr'
        }
    ];
    
    // Add MVOD universal template if MediaPackage is enabled
    if (enableMediaPackage) {
        templateConfigs.push({
            name: `${stackName}_Ott_universal_Avc_Aac_16x9_mvod_no_preset`,
            description: 'Universal HLS MVOD template for MediaPackage VOD',
            resolution: 'universal',
            type: 'universal_mvod'
        });
    }
    
    const createdTemplates = [];
    
    for (const config of templateConfigs) {
        try {
            const template = generateJobTemplate(config, stackName);
            await mediaconvert.createJobTemplate(template).promise();
            createdTemplates.push(config.name);
            console.log(`Created template: ${config.name}`);
        } catch (error) {
            if (error.code !== 'ConflictException') {
                throw error;
            }
            console.log(`Template ${config.name} already exists`);
            createdTemplates.push(config.name);
        }
    }
    
    responseData.Templates = JSON.stringify(createdTemplates);
}

/**
 * Generate MediaConvert job template based on configuration
 */
function generateJobTemplate(config, stackName) {
    const baseTemplate = {
        Name: config.name,
        Description: config.description,
        Category: 'VOD',
        Tags: {
            SolutionId: 'SO0021',
            StackName: stackName,
            TemplateType: config.type,
            Resolution: config.resolution
        },
        Settings: {
            Inputs: [{
                AudioSelectors: {
                    "Audio Selector 1": {
                        DefaultSelection: "DEFAULT",
                        ProgramSelection: 1
                    }
                },
                VideoSelector: {
                    Rotate: "DEGREE_0"
                },
                TimecodeSource: "EMBEDDED"
            }],
            TimecodeConfig: {
                Source: "EMBEDDED"
            },
            OutputGroups: []
        }
    };
    
    // Generate output groups based on template type
    if (config.resolution === 'universal') {
        baseTemplate.Settings.OutputGroups.push(generateUniversalOutputGroup(config.type === 'universal_mvod'));
    } else {
        baseTemplate.Settings.OutputGroups.push(generateStandardOutputGroup(config.resolution, config.type === 'mvod'));
    }
    
    return baseTemplate;
}

/**
 * Generate Universal output group - HLS for MVOD (MediaPackage), CMAF for QVBR
 * Creates adaptive bitrate outputs with proper scaling behavior to prevent upscaling
 */
function generateUniversalOutputGroup(isMVOD) {
    // Define resolution tiers (height, width, bitrate, quality)
    const resolutionTiers = [
        { height: 2160, width: 3840, bitrate: 15000000, quality: 9, name: "2160p" },
        { height: 1080, width: 1920, bitrate: 8500000, quality: 8, name: "1080p" },
        { height: 720, width: 1280, bitrate: 6000000, quality: 8, name: "720p" },
        { height: 540, width: 960, bitrate: 3500000, quality: 7, name: "540p" },
        { height: 360, width: 640, bitrate: 1500000, quality: 7, name: "360p" }
    ];

    if (isMVOD) {
        // Use HLS for MediaPackage VOD (MVOD)
        return {
            Name: "HLS ABR Group",
            OutputGroupSettings: {
                Type: "HLS_GROUP_SETTINGS",
                HlsGroupSettings: {
                    Destination: "s3://DESTINATION_BUCKET/hls/",
                    SegmentLength: 6,
                    MinSegmentLength: 0,
                    DirectoryStructure: "SINGLE_DIRECTORY",
                    ManifestDurationFormat: "INTEGER",
                    StreamInfResolution: "INCLUDE"
                }
            },
            Outputs: [
                // Create outputs for each resolution tier with proper scaling behavior
                ...resolutionTiers.map(tier => 
                    generateVideoOutputWithScaling(tier.name, tier.width, tier.height, tier.bitrate, tier.quality, `_${tier.name}_video`, false)
                ),
                generateAudioOutput(false) // Use M3U8 for HLS
            ]
        };
    } else {
        // Use CMAF for QVBR (standard VOD)
        return {
            Name: "CMAF ABR Group",
            OutputGroupSettings: {
                Type: "CMAF_GROUP_SETTINGS",
                CmafGroupSettings: {
                    Destination: "s3://DESTINATION_BUCKET/cmaf/",
                    SegmentLength: 6,
                    FragmentLength: 6,
                    SegmentControl: "SEGMENTED_FILES",
                    WriteDashManifest: "ENABLED",
                    WriteHlsManifest: "ENABLED",
                    StreamInfResolution: "INCLUDE",
                    WriteSegmentTimelineInRepresentation: "ENABLED"
                }
            },
            Outputs: [
                // Create outputs for each resolution tier with proper scaling behavior
                ...resolutionTiers.map(tier => 
                    generateVideoOutputWithScaling(tier.name, tier.width, tier.height, tier.bitrate, tier.quality, `_${tier.name}_video`, true)
                ),
                generateAudioOutput(true) // Use CMFC for CMAF
            ]
        };
    }
}

/**
 * Generate standard output group for individual resolution templates
 */
function generateStandardOutputGroup(resolution, isMVOD) {
    const resolutionSettings = {
        '2160p': { width: 3840, height: 2160, bitrate: 15000000, quality: 9 },
        '1080p': { width: 1920, height: 1080, bitrate: 8500000, quality: 8 },
        '720p': { width: 1280, height: 720, bitrate: 6000000, quality: 8 }
    };
    
    const settings = resolutionSettings[resolution];
    const outputType = isMVOD ? "HLS_GROUP_SETTINGS" : "DASH_ISO_GROUP_SETTINGS";
    
    return {
        Name: `${resolution} Output Group`,
        OutputGroupSettings: {
            Type: outputType,
            [isMVOD ? "HlsGroupSettings" : "DashIsoGroupSettings"]: isMVOD ? {
                Destination: `s3://DESTINATION_BUCKET/${resolution.toLowerCase()}/`,
                SegmentLength: 6,
                MinSegmentLength: 0,
                DirectoryStructure: "SINGLE_DIRECTORY",
                ManifestDurationFormat: "INTEGER",
                StreamInfResolution: "INCLUDE"
            } : {
                Destination: `s3://DESTINATION_BUCKET/${resolution.toLowerCase()}/`,
                SegmentLength: 6,
                FragmentLength: 6
            }
        },
        Outputs: [
            generateVideoOutput(resolution, settings.width, settings.height, settings.bitrate, settings.quality, `_${resolution}_video`, !isMVOD),
            generateAudioOutput(!isMVOD)
        ]
    };
}

/**
 * Generate video output configuration with scaling behavior to prevent upscaling
 */
function generateVideoOutputWithScaling(resolution, width, height, bitrate, quality, nameModifier, useCMFC = false) {
    return {
        NameModifier: nameModifier,
        VideoDescription: {
            ScalingBehavior: "DEFAULT", // MediaConvert will automatically skip upscaling
            TimecodeInsertion: "DISABLED",
            AntiAlias: "ENABLED",
            Sharpness: 50,
            CodecSettings: {
                Codec: "H_264",
                H264Settings: {
                    InterlaceMode: "PROGRESSIVE",
                    NumberReferenceFrames: 3,
                    Syntax: "DEFAULT",
                    Softness: 0,
                    GopClosedCadence: 1,
                    GopSize: 90,
                    Slices: 1,
                    GopBReference: "DISABLED",
                    SlowPal: "DISABLED",
                    SpatialAdaptiveQuantization: "ENABLED",
                    TemporalAdaptiveQuantization: "ENABLED",
                    FlickerAdaptiveQuantization: "DISABLED",
                    EntropyEncoding: "CABAC",
                    MaxBitrate: bitrate,
                    FramerateControl: "INITIALIZE_FROM_SOURCE",
                    RateControlMode: "QVBR",
                    QvbrSettings: {
                        QvbrQualityLevel: quality,
                        QvbrQualityLevelFineTune: 0
                    },
                    CodecProfile: "HIGH",
                    Telecine: "NONE",
                    MinIInterval: 0,
                    AdaptiveQuantization: "HIGH",
                    CodecLevel: "AUTO",
                    FieldEncoding: "PAFF",
                    SceneChangeDetect: "ENABLED",
                    QualityTuningLevel: "SINGLE_PASS",
                    FramerateConversionAlgorithm: "DUPLICATE_DROP",
                    UnregisteredSeiTimecode: "DISABLED",
                    GopSizeUnits: "FRAMES",
                    ParControl: "INITIALIZE_FROM_SOURCE",
                    NumberBFramesBetweenReferenceFrames: 2,
                    RepeatPps: "DISABLED",
                    DynamicSubGop: "STATIC"
                }
            },
            AfdSignaling: "NONE",
            DropFrameTimecode: "ENABLED",
            RespondToAfd: "NONE",
            ColorMetadata: "INSERT"
        },
        ContainerSettings: useCMFC ? {
            Container: "CMFC",
            CmfcSettings: {}
        } : {
            Container: "M3U8",
            M3u8Settings: {
                AudioFramesPerPes: 4,
                PcrControl: "PCR_EVERY_PES_PACKET",
                PmtPid: 480,
                ProgramNumber: 1,
                PatInterval: 0,
                PmtInterval: 0,
                NielsenId3: "NONE",
                TimedMetadata: "NONE",
                VideoPid: 481,
                AudioPids: [482]
            }
        }
    };
}

/**
 * Generate video output configuration
 */
function generateVideoOutput(resolution, width, height, bitrate, quality, nameModifier, useCMFC = false) {
    return {
        NameModifier: nameModifier,
        VideoDescription: {
            Width: width,
            Height: height,
            ScalingBehavior: "DEFAULT",
            TimecodeInsertion: "DISABLED",
            AntiAlias: "ENABLED",
            Sharpness: 50,
            CodecSettings: {
                Codec: "H_264",
                H264Settings: {
                    InterlaceMode: "PROGRESSIVE",
                    NumberReferenceFrames: 3,
                    Syntax: "DEFAULT",
                    Softness: 0,
                    GopClosedCadence: 1,
                    GopSize: 60,
                    Slices: 1,
                    GopBReference: "DISABLED",
                    SlowPal: "DISABLED",
                    SpatialAdaptiveQuantization: "ENABLED",
                    TemporalAdaptiveQuantization: "ENABLED",
                    FlickerAdaptiveQuantization: "DISABLED",
                    EntropyEncoding: "CABAC",
                    FramerateControl: "INITIALIZE_FROM_SOURCE",
                    RateControlMode: "QVBR",
                    QvbrSettings: {
                        QvbrQualityLevel: quality,
                        MaxAverageBitrate: bitrate
                    },
                    MaxBitrate: bitrate,
                    CodecProfile: "HIGH",
                    Telecine: "NONE",
                    MinIInterval: 0,
                    AdaptiveQuantization: "HIGH",
                    CodecLevel: "AUTO",
                    FieldEncoding: "PAFF",
                    SceneChangeDetect: "ENABLED",
                    QualityTuningLevel: "MULTI_PASS_HQ",
                    FramerateConversionAlgorithm: "DUPLICATE_DROP",
                    UnregisteredSeiTimecode: "DISABLED",
                    GopSizeUnits: "FRAMES",
                    ParControl: "INITIALIZE_FROM_SOURCE",
                    NumberBFramesBetweenReferenceFrames: 2,
                    RepeatPps: "DISABLED",
                    DynamicSubGop: "STATIC"
                }
            },
            AfdSignaling: "NONE",
            DropFrameTimecode: "ENABLED",
            RespondToAfd: "NONE",
            ColorMetadata: "INSERT"
        },
        ContainerSettings: useCMFC ? {
            Container: "CMFC",
            CmfcSettings: {}
        } : {
            Container: "M3U8",
            M3u8Settings: {
                AudioFramesPerPes: 4,
                PcrControl: "PCR_EVERY_PES_PACKET",
                PmtPid: 480,
                ProgramNumber: 1,
                PatInterval: 0,
                PmtInterval: 0,
                NielsenId3: "NONE",
                TimedMetadata: "NONE",
                VideoPid: 481,
                AudioPids: [482]
            }
        }
    };
}

/**
 * Generate audio output configuration
 */
function generateAudioOutput(useCMFC = false) {
    return {
        NameModifier: "_audio",
        AudioDescriptions: [{
            AudioTypeControl: "FOLLOW_INPUT",
            AudioSourceName: "Audio Selector 1",
            CodecSettings: {
                Codec: "AAC",
                AacSettings: {
                    AudioDescriptionBroadcasterMix: "NORMAL",
                    Bitrate: 128000,
                    RateControlMode: "CBR",
                    CodecProfile: "LC",
                    CodingMode: "CODING_MODE_2_0",
                    RawFormat: "NONE",
                    SampleRate: 48000,
                    Specification: "MPEG4"
                }
            },
            LanguageCodeControl: "FOLLOW_INPUT",
            AudioType: 0
        }],
        ContainerSettings: useCMFC ? {
            Container: "CMFC",
            CmfcSettings: {}
        } : {
            Container: "M3U8",
            M3u8Settings: {
                AudioFramesPerPes: 4,
                PcrControl: "PCR_EVERY_PES_PACKET",
                PmtPid: 480,
                ProgramNumber: 1,
                PatInterval: 0,
                PmtInterval: 0,
                VideoPid: 481,
                AudioPids: [482]
            }
        }
    };
}

/**
 * Handle MediaPackage VOD creation
 */
async function handleMediaPackageVod(properties, responseData) {
    const stackName = properties.StackName;
    const groupId = properties.GroupId;
    const packagingConfigs = properties.PackagingConfigurations.split(',');
    const distributionId = properties.DistributionId;
    const enableMediaPackage = properties.EnableMediaPackage === 'true';
    
    if (!enableMediaPackage) {
        responseData.GroupId = '';
        responseData.GroupDomainName = '';
        return;
    }
    
    try {
        // Create packaging group
        await mediapackageVod.createPackagingGroup({
            Id: groupId,
            Tags: {
                SolutionId: 'SO0021',
                StackName: stackName
            }
        }).promise();
        
        console.log(`Created packaging group: ${groupId}`);
    } catch (error) {
        if (error.code !== 'UnprocessableEntityException') {
            throw error;
        }
        console.log(`Packaging group ${groupId} already exists`);
    }
    
    // Create packaging configurations - HLS, DASH, MSS, and CMAF
    const createdConfigs = [];
    const configTypes = ['HLS', 'DASH', 'MSS', 'CMAF'];
    
    for (const configType of configTypes) {
        const configId = `${stackName}-${configType.toLowerCase()}-packaging-config`;
        
        try {
            await createPackagingConfiguration(configId, groupId, configType, stackName);
            createdConfigs.push(configId);
            console.log(`Created packaging configuration: ${configId}`);
        } catch (error) {
            if (error.code !== 'UnprocessableEntityException') {
                throw error;
            }
            console.log(`Packaging configuration ${configId} already exists`);
            createdConfigs.push(configId);
        }
    }
    
    // Get packaging group details
    const groupDetails = await mediapackageVod.describePackagingGroup({ Id: groupId }).promise();
    
    responseData.GroupId = groupId;
    responseData.GroupDomainName = groupDetails.DomainName;
    responseData.PackagingConfigurations = JSON.stringify(createdConfigs);
    
    // Update CloudFront distribution if specified
    if (distributionId) {
        await updateCloudFrontDistribution(distributionId, groupDetails.DomainName);
    }
}

/**
 * Create packaging configuration based on type
 */
async function createPackagingConfiguration(configId, groupId, configType, stackName) {
    const baseConfig = {
        Id: configId,
        PackagingGroupId: groupId,
        Tags: {
            SolutionId: 'SO0021',
            StackName: stackName,
            Format: configType
        }
    };
    
    switch (configType.toUpperCase()) {
        case 'HLS':
            baseConfig.HlsPackage = {
                HlsManifests: [{
                    AdMarkers: "NONE",
                    IncludeIframeOnlyStream: false,
                    ManifestName: "index",
                    ProgramDateTimeIntervalSeconds: 0,
                    RepeatExtXKey: false,
                    StreamSelection: {
                        MaxVideoBitsPerSecond: 2147483647,
                        MinVideoBitsPerSecond: 0,
                        StreamOrder: "ORIGINAL"
                    }
                }],
                SegmentDurationSeconds: 10,
                UseAudioRenditionGroup: false
            };
            break;
            
        case 'DASH':
            baseConfig.DashPackage = {
                DashManifests: [{
                    ManifestName: "index",
                    StreamSelection: {
                        MaxVideoBitsPerSecond: 2147483647,
                        MinVideoBitsPerSecond: 0,
                        StreamOrder: "ORIGINAL"
                    }
                }],
                SegmentDurationSeconds: 10
            };
            break;
            
        case 'MSS':
            baseConfig.MssPackage = {
                MssManifests: [{
                    ManifestName: "index",
                    StreamSelection: {
                        MaxVideoBitsPerSecond: 2147483647,
                        MinVideoBitsPerSecond: 0,
                        StreamOrder: "ORIGINAL"
                    }
                }],
                SegmentDurationSeconds: 10
            };
            break;
            
        case 'CMAF':
            baseConfig.CmafPackage = {
                HlsManifests: [{
                    AdMarkers: "NONE",
                    IncludeIframeOnlyStream: false,
                    ManifestName: "index",
                    ProgramDateTimeIntervalSeconds: 0,
                    RepeatExtXKey: false,
                    StreamSelection: {
                        MaxVideoBitsPerSecond: 2147483647,
                        MinVideoBitsPerSecond: 0,
                        StreamOrder: "ORIGINAL"
                    }
                }],
                SegmentDurationSeconds: 10
            };
            break;
            
        case 'HLS_CMAF':
            // HLS manifest with CMAF segments
            baseConfig.CmafPackage = {
                HlsManifests: [{
                    AdMarkers: "NONE",
                    IncludeIframeOnlyStream: false,
                    ManifestName: "index",
                    ProgramDateTimeIntervalSeconds: 0,
                    RepeatExtXKey: false,
                    StreamSelection: {
                        MaxVideoBitsPerSecond: 2147483647,
                        MinVideoBitsPerSecond: 0,
                        StreamOrder: "ORIGINAL"
                    }
                }],
                SegmentDurationSeconds: 10
            };
            break;
            
        case 'DASH_CMAF':
            // DASH manifest with CMAF segments
            baseConfig.CmafPackage = {
                DashManifests: [{
                    ManifestName: "index",
                    StreamSelection: {
                        MaxVideoBitsPerSecond: 2147483647,
                        MinVideoBitsPerSecond: 0,
                        StreamOrder: "ORIGINAL"
                    }
                }],
                SegmentDurationSeconds: 10
            };
            break;
            
        default:
            throw new Error(`Unsupported packaging configuration type: ${configType}`);
    }
    
    return await mediapackageVod.createPackagingConfiguration(baseConfig).promise();
}

/**
 * Update CloudFront distribution with MediaPackage origin
 */
async function updateCloudFrontDistribution(distributionId, mediaPackageDomain) {
    // This is a placeholder for CloudFront integration
    // In practice, you would update the distribution configuration
    console.log(`Would update CloudFront distribution ${distributionId} with MediaPackage domain ${mediaPackageDomain}`);
}

/**
 * Delete MediaConvert templates
 */
async function deleteMediaConvertTemplates(properties) {
    const stackName = properties.StackName;
    const endpoint = properties.EndPoint;
    
    mediaconvert.endpoint = endpoint;
    
    const templateNames = [
        `${stackName}_Ott_2160p_Avc_Aac_16x9_qvbr_no_preset`,
        `${stackName}_Ott_1080p_Avc_Aac_16x9_qvbr_no_preset`,
        `${stackName}_Ott_720p_Avc_Aac_16x9_qvbr_no_preset`,
        `${stackName}_Ott_2160p_Avc_Aac_16x9_mvod_no_preset`,
        `${stackName}_Ott_1080p_Avc_Aac_16x9_mvod_no_preset`,
        `${stackName}_Ott_720p_Avc_Aac_16x9_mvod_no_preset`,
        `${stackName}_Ott_universal_Avc_Aac_16x9_qvbr_no_preset`,
        `${stackName}_Ott_universal_Avc_Aac_16x9_mvod_no_preset`
    ];
    
    for (const templateName of templateNames) {
        try {
            await mediaconvert.deleteJobTemplate({ Name: templateName }).promise();
            console.log(`Deleted template: ${templateName}`);
        } catch (error) {
            if (error.code !== 'NotFoundException') {
                console.error(`Error deleting template ${templateName}:`, error);
            }
        }
    }
}

/**
 * Delete MediaPackage VOD resources
 */
async function deleteMediaPackageVod(properties) {
    const stackName = properties.StackName;
    const groupId = properties.GroupId;
    const packagingConfigs = properties.PackagingConfigurations.split(',');
    
    // Delete packaging configurations first - HLS, DASH, MSS, and CMAF
    const configsToDelete = [
        `${stackName}-hls-packaging-config`,
        `${stackName}-dash-packaging-config`,
        `${stackName}-mss-packaging-config`,
        `${stackName}-cmaf-packaging-config`
    ];
    
    for (const configId of configsToDelete) {
        try {
            await mediapackageVod.deletePackagingConfiguration({ Id: configId }).promise();
            console.log(`Deleted packaging configuration: ${configId}`);
        } catch (error) {
            if (error.code !== 'NotFoundException') {
                console.error(`Error deleting packaging configuration ${configId}:`, error);
            }
        }
    }
    
    // Delete packaging group
    try {
        await mediapackageVod.deletePackagingGroup({ Id: groupId }).promise();
        console.log(`Deleted packaging group: ${groupId}`);
    } catch (error) {
        if (error.code !== 'NotFoundException') {
            console.error(`Error deleting packaging group ${groupId}:`, error);
        }
    }
}

/**
 * Handle S3 notification configuration
 */
async function handleS3Notification(properties) {
    // Implementation for S3 notification setup
    console.log('Setting up S3 notifications:', properties);
}

/**
 * Delete S3 notification configuration
 */
async function deleteS3Notification(properties) {
    // Implementation for S3 notification cleanup
    console.log('Cleaning up S3 notifications:', properties);
}

/**
 * Generate UUID
 */
function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

/**
 * Send anonymized metrics
 */
async function sendAnonymizedMetric(properties) {
    if (properties.SendAnonymizedMetric === 'Yes') {
        const metric = {
            SolutionId: properties.SolutionId,
            UUID: properties.UUID,
            Version: properties.Version,
            Transcoder: properties.Transcoder,
            WorkflowTrigger: properties.WorkflowTrigger,
            Glacier: properties.Glacier,
            FrameCapture: properties.FrameCapture,
            EnableMediaPackage: properties.EnableMediaPackage
        };
        
        console.log('Sending anonymized metric:', metric);
        // Implementation would send metrics to AWS Solutions metrics endpoint
    }
}

/**
 * Send CloudFormation response
 */
async function sendResponse(event, context, responseStatus, responseData) {
    const responseBody = JSON.stringify({
        Status: responseStatus,
        Reason: `See the details in CloudWatch Log Stream: ${context.logStreamName}`,
        PhysicalResourceId: context.logStreamName,
        StackId: event.StackId,
        RequestId: event.RequestId,
        LogicalResourceId: event.LogicalResourceId,
        Data: responseData
    });
    
    console.log('Response body:\n', responseBody);
    
    const parsedUrl = url.parse(event.ResponseURL);
    const options = {
        hostname: parsedUrl.hostname,
        port: 443,
        path: parsedUrl.path,
        method: 'PUT',
        headers: {
            'content-type': '',
            'content-length': responseBody.length
        }
    };
    
    return new Promise((resolve, reject) => {
        const request = https.request(options, (response) => {
            console.log('Status code:', response.statusCode);
            console.log('Status message:', response.statusMessage);
            resolve();
        });
        
        request.on('error', (error) => {
            console.log('send(..) failed executing https.request(..):', error);
            reject(error);
        });
        
        request.write(responseBody);
        request.end();
    });
}
