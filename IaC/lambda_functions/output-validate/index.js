const { DynamoDBDocument } = require("@aws-sdk/lib-dynamodb");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { S3 } = require("@aws-sdk/client-s3");

const buildUrl = (originalValue) => originalValue.slice(5).split('/').splice(1).join('/');

exports.handler = async (event) => {
    console.log(`REQUEST:: ${JSON.stringify(event, null, 2)}`);

    const dynamo = DynamoDBDocument.from(new DynamoDBClient({ 
        region: process.env.AWS_REGION,
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    }));

    const s3 = new S3({customUserAgent: process.env.SOLUTION_IDENTIFIER});

    let data = {};

    try {
        // Get Config from DynamoDB (data required for the workflow)
        let params = {
            TableName: process.env.DynamoDBTable,
            Key: {
                guid: event.detail.userMetadata.guid,
            }
        };

        data = await dynamo.get(params);
        data = data.Item;

        data.encodingOutput = event;
        data.workflowStatus = 'Complete';
        data.endTime = new Date().toISOString();

        // Parse MediaConvert Output and generate CloudFront URLS.
        if (event.detail && event.detail.outputGroupDetails) {
            event.detail.outputGroupDetails.forEach(output => {
                console.log(`${output.type} found in outputs`);

                switch (output.type) {
                case 'HLS_GROUP':
                    if (output.playlistFilePaths && output.playlistFilePaths.length > 0) {
                        data.hlsPlaylist = output.playlistFilePaths[0];
                        data.hlsUrl = `https://${data.cloudFront}/${buildUrl(data.hlsPlaylist)}`;
                    }
                    break;

                case 'DASH_ISO_GROUP':
                    if (output.playlistFilePaths && output.playlistFilePaths.length > 0) {
                        data.dashPlaylist = output.playlistFilePaths[0];
                        data.dashUrl = `https://${data.cloudFront}/${buildUrl(data.dashPlaylist)}`;
                    }
                    break;

                case 'FILE_GROUP':
                    let files = [];
                    let urls = [];
                    if (output.outputDetails) {
                        output.outputDetails.forEach((file) => {
                            if (file.outputFilePaths && file.outputFilePaths.length > 0) {
                                files.push(file.outputFilePaths[0]);
                                urls.push(`https://${data.cloudFront}/${buildUrl(file.outputFilePaths[0])}`);
                            }
                        });
                    }
                    
                    if (files.length > 0 && files[0].split('.').pop() === 'mp4') {
                        data.mp4Outputs = files;
                        data.mp4Urls = urls;
                    }
                    break;

                case 'MS_SMOOTH_GROUP':
                    if (output.playlistFilePaths && output.playlistFilePaths.length > 0) {
                        data.mssPlaylist = output.playlistFilePaths[0];
                        data.mssUrl = `https://${data.cloudFront}/${buildUrl(data.mssPlaylist)}`;
                    }
                    break;

                case 'CMAF_GROUP':
                    if (output.playlistFilePaths && output.playlistFilePaths.length >= 2) {
                        data.cmafDashPlaylist = output.playlistFilePaths[0];
                        data.cmafDashUrl = `https://${data.cloudFront}/${buildUrl(data.cmafDashPlaylist)}`;

                        data.cmafHlsPlaylist = output.playlistFilePaths[1];
                        data.cmafHlsUrl = `https://${data.cloudFront}/${buildUrl(data.cmafHlsPlaylist)}`;
                        
                        // Set hlsPlaylist for MediaPackage compatibility with CMAF universal template
                        data.hlsPlaylist = data.cmafHlsPlaylist;
                        data.hlsUrl = data.cmafHlsUrl;
                    }
                    break;

                default:
                    console.log(`Unknown output type: ${output.type}`);
                }
            });
        } else {
            console.log('No outputGroupDetails found in event.detail');
        }

        // Handle frame capture thumbnails if enabled
        if (data.frameCapture) {
            data.thumbNails = [];
            data.thumbNailsUrls = [];

            params = {
                Bucket: data.destBucket,
                Prefix: `${data.guid}/thumbnails/`,
            };

            let thumbNails = await s3.listObjectsV2(params);

            if (thumbNails.Contents && thumbNails.Contents.length > 0) {
                let lastImg = thumbNails.Contents[thumbNails.Contents.length - 1];
                data.thumbNails.push(`s3://${data.destBucket}/${lastImg.Key}`);
                data.thumbNailsUrls.push(`https://${data.cloudFront}/${lastImg.Key}`);
            } else {
                console.log('No thumbnails found in S3, skipping thumbnail processing');
                // Don't throw error, just skip thumbnail processing
            }
        }

    } catch (err) {
        console.error('Error:', err);
        data.workflowStatus = 'Error';
        data.error = err.message;
        throw err;
    }

    return data;
};