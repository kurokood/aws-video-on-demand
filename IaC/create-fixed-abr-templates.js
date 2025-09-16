const { MediaConvertClient, CreateJobTemplateCommand, DescribeEndpointsCommand } = require('@aws-sdk/client-mediaconvert');

async function createABRTemplates() {
    try {
        // Get MediaConvert endpoint
        const client = new MediaConvertClient({ region: 'us-east-1' });
        const endpoints = await client.send(new DescribeEndpointsCommand({}));
        const endpoint = endpoints.Endpoints[0].Url;
        console.log('MediaConvert endpoint:', endpoint);

        const createClient = new MediaConvertClient({ 
            region: 'us-east-1',
            endpoint: endpoint
        });

        const stackName = 'vod';
        const enableMediaPackage = true;

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

        // Create templates for each resolution
        for (const [resolution, ladder] of Object.entries(abrLadders)) {
            // Create QVBR template (CMAF)
            const qvbrTemplateName = `${stackName}_Ott_${resolution}_Avc_Aac_16x9_qvbr_no_preset`;
            await createTemplate(createClient, qvbrTemplateName, resolution, ladder, false);
            console.log(`Created QVBR template: ${qvbrTemplateName}`);

            // Create MVOD template (HLS) if MediaPackage is enabled
            if (enableMediaPackage) {
                const mvodTemplateName = `${stackName}_Ott_${resolution}_Avc_Aac_16x9_mvod_no_preset`;
                await createTemplate(createClient, mvodTemplateName, resolution, ladder, true);
                console.log(`Created MVOD template: ${mvodTemplateName}`);
            }
        }
    } catch (error) {
        console.error('Error:', error);
    }
}

// Create a single template
async function createTemplate(client, templateName, resolution, ladder, isMVOD) {
    const outputType = isMVOD ? "HLS_GROUP_SETTINGS" : "DASH_ISO_GROUP_SETTINGS";
    
    // Generate video outputs for each rendition in the ladder
    const videoOutputs = ladder.map(tier => 
        generateVideoOutput(tier.name, tier.width, tier.height, tier.bitrate, tier.quality, `_${tier.name}_video`, !isMVOD, isMVOD)
    );

    const template = {
        Name: templateName,
        Description: `${resolution} ABR template with multiple renditions (no upscaling)`,
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
            OutputGroups: [{
                Name: `${resolution} ABR Output Group`,
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
                    ...videoOutputs,
                    generateAudioOutput(!isMVOD, isMVOD)
                ]
            }]
        }
    };

    try {
        await client.send(new CreateJobTemplateCommand(template));
        console.log(`Successfully created template: ${templateName}`);
    } catch (error) {
        console.error(`Error creating template ${templateName}:`, error.message);
    }
}

// Generate video output configuration
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
        ContainerSettings: isMVOD ? {
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
        } : {
            Container: "CMFC",
            CmfcSettings: {}
        }
    };
}

// Generate audio output configuration
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
        ContainerSettings: isMVOD ? {
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
        } : {
            Container: "CMFC",
            CmfcSettings: {}
        }
    };
}

// Run the script
createABRTemplates();
