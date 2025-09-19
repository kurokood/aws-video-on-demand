const { MediaConvert } = require('@aws-sdk/client-mediaconvert');
const { MediaPackageVod } = require('@aws-sdk/client-mediapackage-vod');
const { CloudFront } = require('@aws-sdk/client-cloudfront');
const { S3 } = require('@aws-sdk/client-s3');
const https = require('https');
const url = require('url');

// Initialize AWS services (endpoints will be set dynamically)
let mediaconvert;
let mediapackageVod;
let cloudfront;
let s3;

/**
 * Custom Resource Lambda Function for MediaConvert and MediaPackage
 * Based on Video on Demand on AWS Solution
 */
exports.handler = async (event, context) => {
    console.log('Received event:', JSON.stringify(event, null, 2));
    
    // Initialize AWS services
    mediaconvert = new MediaConvert({
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    });
    mediapackageVod = new MediaPackageVod({
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    });
    cloudfront = new CloudFront({
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    });
    s3 = new S3({
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    });
    
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
    try {
        const params = {
            MaxResults: 1
        };
        
        const result = await mediaconvert.describeEndpoints(params);
        console.log('MediaConvert endpoints:', JSON.stringify(result, null, 2));
        return result.Endpoints[0].Url;
    } catch (error) {
        console.error('Error getting MediaConvert endpoint:', error);
        throw error;
    }
}

/**
 * Handle MediaConvert template creation
 */
async function handleMediaConvertTemplates(properties, responseData) {
    const stackName = properties.StackName;
    const enableMediaPackage = properties.EnableMediaPackage === 'true';
    const enableNewTemplates = properties.EnableNewTemplates === 'Yes' || properties.EnableNewTemplates === true;
    const endpoint = properties.EndPoint;
    
    console.log(`MediaConvert Template Creation - Stack: ${stackName}, EnableMediaPackage: ${properties.EnableMediaPackage} (${enableMediaPackage}), EnableNewTemplates: ${properties.EnableNewTemplates} (${enableNewTemplates}), Endpoint: ${endpoint}`);
    
    // Set custom endpoint for MediaConvert
    mediaconvert.endpoint = endpoint;
    
    // Define template configurations based on MediaPackage setting
    let templateConfigs;
    
    if (enableMediaPackage) {
        // When MediaPackage is enabled, create only MVOD templates
        templateConfigs = [
            {
                name: `${stackName}_Ott_2160p_Avc_Aac_16x9_mvod_no_preset`,
                description: '2160p MVOD template for MediaPackage VOD',
                resolution: '2160p',
                type: 'mvod'
            },
            {
                name: `${stackName}_Ott_1080p_Avc_Aac_16x9_mvod_no_preset`,
                description: '1080p MVOD template for MediaPackage VOD',
                resolution: '1080p',
                type: 'mvod'
            },
            {
                name: `${stackName}_Ott_720p_Avc_Aac_16x9_mvod_no_preset`,
                description: '720p MVOD template for MediaPackage VOD',
                resolution: '720p',
                type: 'mvod'
            }
        ];
    } else {
        // When MediaPackage is disabled, create only QVBR templates
        templateConfigs = [
            {
                name: `${stackName}_Ott_2160p_Avc_Aac_16x9_qvbr_no_preset`,
                description: '2160p QVBR template for standard VOD',
                resolution: '2160p',
                type: 'qvbr'
            },
            {
                name: `${stackName}_Ott_1080p_Avc_Aac_16x9_qvbr_no_preset`,
                description: '1080p QVBR template for standard VOD',
                resolution: '1080p',
                type: 'qvbr'
            },
            {
                name: `${stackName}_Ott_720p_Avc_Aac_16x9_qvbr_no_preset`,
                description: '720p QVBR template for standard VOD',
                resolution: '720p',
                type: 'qvbr'
            }
        ];
    }
    
    const createdTemplates = [];
    
    for (const config of templateConfigs) {
        try {
            const template = generateJobTemplate(config, stackName);
            console.log(`Creating template: ${config.name}`);
            console.log('Template configuration:', JSON.stringify(template, null, 2));
            
            await mediaconvert.createJobTemplate(template);
            createdTemplates.push(config.name);
            console.log(`Successfully created template: ${config.name}`);
        } catch (error) {
            console.error(`Error creating template ${config.name}:`, error);
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
    
    // Generate output groups based on template type - all templates are now individual resolution-specific
    baseTemplate.Settings.OutputGroups.push(generateStandardOutputGroup(config.resolution, config.type === 'mvod'));
    
    return baseTemplate;
}

/**
 * Generate standard output group for individual resolution templates
 * Creates ABR ladder starting from source resolution and going down to lower resolutions
 * HLS for MVOD (MediaPackage) or CMAF for QVBR
 */
function generateStandardOutputGroup(resolution, isMVOD) {
    // Define ABR ladders for each source resolution (no upscaling)
    const abrLadders = {
        '2160p': [
            { height: 2160, width: 3840, bitrate: 15000000, quality: 9, name: "2160p" },
            { height: 1080, width: 1920, bitrate: 8500000, quality: 8, name: "1080p" },
            { height: 720, width: 1280, bitrate: 6000000, quality: 8, name: "720p" },
            { height: 480, width: 854, bitrate: 3000000, quality: 7, name: "480p" },
            { height: 360, width: 640, bitrate: 1500000, quality: 7, name: "360p" }
        ],
        '1080p': [
            { height: 1080, width: 1920, bitrate: 8500000, quality: 8, name: "1080p" },
            { height: 720, width: 1280, bitrate: 6000000, quality: 8, name: "720p" },
            { height: 480, width: 854, bitrate: 3000000, quality: 7, name: "480p" },
            { height: 360, width: 640, bitrate: 1500000, quality: 7, name: "360p" }
        ],
        '720p': [
            { height: 720, width: 1280, bitrate: 6000000, quality: 8, name: "720p" },
            { height: 480, width: 854, bitrate: 3000000, quality: 7, name: "480p" },
            { height: 360, width: 640, bitrate: 1500000, quality: 7, name: "360p" }
        ]
    };
    
    const ladder = abrLadders[resolution];
    if (!ladder) {
        throw new Error(`Unsupported resolution: ${resolution}`);
    }
    
    // For CMAF, we need both HLS and DASH manifests with CMAF segments
    if (isMVOD) {
        // MediaPackage VOD - use HLS with CMAF segments
        return {
            Name: `${resolution} HLS CMAF Output Group`,
            OutputGroupSettings: {
                Type: "CMAF_GROUP_SETTINGS",
                CmafGroupSettings: {
                    Destination: `s3://DESTINATION_BUCKET/${resolution.toLowerCase()}/hls/cmaf/`,
                    SegmentLength: 6,
                    FragmentLength: 6,
                    SegmentControl: "SEGMENTED_FILES",
                    WriteDashManifest: "DISABLED",
                    WriteHlsManifest: "ENABLED",
                    StreamInfResolution: "INCLUDE",
                    WriteSegmentTimelineInRepresentation: "ENABLED"
                }
            },
            Outputs: [
                ...ladder.map(tier => 
                    generateVideoOutput(tier.name, tier.width, tier.height, tier.bitrate, tier.quality, `_${tier.name}_video`, true, true)
                ),
                generateAudioOutput(true, true)
            ]
        };
    } else {
        // Standard VOD - use both HLS and DASH manifests with CMAF segments
        return {
            Name: `${resolution} CMAF Output Group`,
            OutputGroupSettings: {
                Type: "CMAF_GROUP_SETTINGS",
                CmafGroupSettings: {
                    Destination: `s3://DESTINATION_BUCKET/${resolution.toLowerCase()}/cmaf/`,
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
                ...ladder.map(tier => 
                    generateVideoOutput(tier.name, tier.width, tier.height, tier.bitrate, tier.quality, `_${tier.name}_video`, true, false)
                ),
                generateAudioOutput(true, false)
            ]
        };
    }
}


/**
 * Generate video output configuration
 */
function generateVideoOutput(resolution, width, height, bitrate, quality, nameModifier, useCMFC = false, isMVOD = false) {
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
        ContainerSettings: {
            Container: "CMFC",
            CmfcSettings: {}
        }
    };
}

/**
 * Generate audio output configuration
 */
function generateAudioOutput(useCMFC = false, isMVOD = false) {
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
        ContainerSettings: {
            Container: "CMFC",
            CmfcSettings: {}
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
        });
        
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
    const groupDetails = await mediapackageVod.describePackagingGroup({ Id: groupId });
    
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
    
    return await mediapackageVod.createPackagingConfiguration(baseConfig);
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
    const enableMediaPackage = properties.EnableMediaPackage === 'true';
    
    // Set custom endpoint for MediaConvert
    mediaconvert.endpoint = endpoint;
    
    // Define template names based on MediaPackage setting
    let templateNames;
    
    if (enableMediaPackage) {
        // When MediaPackage is enabled, delete only MVOD templates
        templateNames = [
            `${stackName}_Ott_2160p_Avc_Aac_16x9_mvod_no_preset`,
            `${stackName}_Ott_1080p_Avc_Aac_16x9_mvod_no_preset`,
            `${stackName}_Ott_720p_Avc_Aac_16x9_mvod_no_preset`
        ];
    } else {
        // When MediaPackage is disabled, delete only QVBR templates
        templateNames = [
            `${stackName}_Ott_2160p_Avc_Aac_16x9_qvbr_no_preset`,
            `${stackName}_Ott_1080p_Avc_Aac_16x9_qvbr_no_preset`,
            `${stackName}_Ott_720p_Avc_Aac_16x9_qvbr_no_preset`
        ];
    }
    
    for (const templateName of templateNames) {
        try {
            await mediaconvert.deleteJobTemplate({ Name: templateName });
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
            await mediapackageVod.deletePackagingConfiguration({ Id: configId });
            console.log(`Deleted packaging configuration: ${configId}`);
        } catch (error) {
            if (error.code !== 'NotFoundException') {
                console.error(`Error deleting packaging configuration ${configId}:`, error);
            }
        }
    }
    
    // Delete packaging group
    try {
        await mediapackageVod.deletePackagingGroup({ Id: groupId });
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
