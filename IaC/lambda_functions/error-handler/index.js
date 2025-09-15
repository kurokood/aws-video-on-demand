const { SNS } = require("@aws-sdk/client-sns");
const { DynamoDBDocument } = require("@aws-sdk/lib-dynamodb");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");

exports.handler = async (event) => {
    console.log(`REQUEST:: ${JSON.stringify(event, null, 2)}`);

    const sns = new SNS({ 
        region: process.env.AWS_REGION,
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    });
    
    const dynamo = DynamoDBDocument.from(new DynamoDBClient({ 
        region: process.env.AWS_REGION,
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    }));

    try {
        // Update DynamoDB with error status
        if (event.guid) {
            await dynamo.update({
                TableName: process.env.DynamoDBTable,
                Key: { guid: event.guid },
                UpdateExpression: 'SET workflowStatus = :status, errorMessage = :error, #ts = :timestamp',
                ExpressionAttributeNames: {
                    '#ts': 'timestamp'
                },
                ExpressionAttributeValues: {
                    ':status': 'Error',
                    ':error': event.error || 'Unknown error',
                    ':timestamp': new Date().toISOString()
                }
            });
        }

        // Send SNS notification only if enabled
        const enableSns = event.enableSns || (process.env.EnableSns === "true");
        
        if (enableSns) {
            const message = {
                guid: event.guid,
                error: event.error || 'Unknown error',
                function: event.function || 'Unknown function',
                timestamp: new Date().toISOString()
            };

            await sns.publish({
                TopicArn: process.env.SnsTopic,
                Subject: 'Video on Demand Workflow Error',
                Message: JSON.stringify(message, null, 2)
            });
        }

        console.log('Error handled successfully');
    } catch (err) {
        console.error('Error in error handler:', err);
        throw err;
    }

    return event;
};