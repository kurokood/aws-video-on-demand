const { SQS } = require("@aws-sdk/client-sqs");

exports.handler = async (event) => {
    console.log(`REQUEST:: ${JSON.stringify(event, null, 2)}`);

    const sqs = new SQS({ 
        region: process.env.AWS_REGION,
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    });

    try {
        if (event.enableSqs) {
            const message = {
                guid: event.guid,
                status: event.workflowStatus,
                srcVideo: event.srcVideo,
                timestamp: new Date().toISOString()
            };

            if (event.outputFiles) {
                message.outputFiles = event.outputFiles;
            }

            await sqs.sendMessage({
                QueueUrl: process.env.SqsQueue,
                MessageBody: JSON.stringify(message)
            });

            console.log('SQS message sent successfully');
        }
    } catch (err) {
        console.error('Error:', err);
        throw err;
    }

    return event;
};