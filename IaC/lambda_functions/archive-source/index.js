const { S3 } = require("@aws-sdk/client-s3");

exports.handler = async (event) => {
    console.log(`REQUEST:: ${JSON.stringify(event, null, 2)}`);

    const s3 = new S3({ customUserAgent: process.env.SOLUTION_IDENTIFIER });

    try {
        if (event.archiveSource && event.archiveSource !== 'DISABLED') {
            const tagParams = {
                Bucket: event.srcBucket,
                Key: event.srcVideo,
                Tagging: {
                    TagSet: [{
                        Key: event.workflowName,
                        Value: event.archiveSource
                    }]
                }
            };

            await s3.putObjectTagging(tagParams);
            console.log(`Tagged ${event.srcVideo} for ${event.archiveSource} archiving`);
        }
    } catch (err) {
        console.error('Error:', err);
        throw err;
    }

    return event;
};