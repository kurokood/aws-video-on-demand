const { SNS } = require("@aws-sdk/client-sns");

exports.handler = async (event) => {
    console.log(`REQUEST:: ${JSON.stringify(event, null, 2)}`);

    const sns = new SNS({ 
        region: process.env.AWS_REGION,
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    });

    try {
        // Check both event.enableSns and environment variable for backward compatibility
        const enableSns = event.enableSns || (process.env.EnableSns === "true");
        
        if (enableSns) {
            const message = {
                guid: event.guid,
                status: event.workflowStatus,
                srcVideo: event.srcVideo,
                timestamp: new Date().toISOString()
            };

            if (event.outputFiles) {
                message.outputFiles = event.outputFiles;
            }

            await sns.publish({
                TopicArn: process.env.SnsTopic,
                Subject: `Video on Demand Workflow ${event.workflowStatus}`,
                Message: JSON.stringify(message, null, 2)
            });

            console.log('SNS notification sent successfully');
        }
    } catch (err) {
        console.error('Error:', err);
        throw err;
    }

    return event;
};