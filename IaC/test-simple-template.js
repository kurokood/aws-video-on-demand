const { MediaConvertClient, CreateJobTemplateCommand, DescribeEndpointsCommand } = require('@aws-sdk/client-mediaconvert');

async function testCreateTemplate() {
    try {
        // Get MediaConvert endpoint
        const client = new MediaConvertClient({ region: 'us-east-1' });
        const endpoints = await client.send(new DescribeEndpointsCommand({}));
        const endpoint = endpoints.Endpoints[0].Url;
        console.log('MediaConvert endpoint:', endpoint);

        // Create a simple template
        const template = {
            Name: 'test-simple-template',
            Description: 'Test template',
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
                    Name: "File Group",
                    OutputGroupSettings: {
                        Type: "FILE_GROUP_SETTINGS",
                        FileGroupSettings: {
                            Destination: "s3://test-bucket/"
                        }
                    },
                    Outputs: [{
                        NameModifier: "_test",
                        VideoDescription: {
                            Width: 1280,
                            Height: 720,
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
                                        QvbrQualityLevel: 8,
                                        MaxAverageBitrate: 6000000
                                    },
                                    MaxBitrate: 6000000,
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
                            Container: "MP4",
                            Mp4Settings: {
                                CslgAtom: "INCLUDE",
                                FreeSpaceBox: "EXCLUDE",
                                MoovPlacement: "PROGRESSIVE_DOWNLOAD"
                            }
                        }
                    }]
                }]
            }
        };

        const createClient = new MediaConvertClient({ 
            region: 'us-east-1',
            endpoint: endpoint
        });

        const result = await createClient.send(new CreateJobTemplateCommand(template));
        console.log('Template created successfully:', result.JobTemplate.Name);
    } catch (error) {
        console.error('Error:', error);
    }
}

testCreateTemplate();
