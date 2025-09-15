const { DynamoDBDocument } = require("@aws-sdk/lib-dynamodb");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");

exports.handler = async (event) => {
    console.log(`REQUEST:: ${JSON.stringify(event, null, 2)}`);

    const dynamo = DynamoDBDocument.from(new DynamoDBClient({ 
        region: process.env.AWS_REGION,
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    }));

    try {
        const params = {
            TableName: process.env.DynamoDBTable,
            Key: { guid: event.guid },
            UpdateExpression: 'SET workflowStatus = :status, #ts = :timestamp',
            ExpressionAttributeNames: {
                '#ts': 'timestamp'
            },
            ExpressionAttributeValues: {
                ':status': event.workflowStatus || 'Processing',
                ':timestamp': new Date().toISOString()
            }
        };

        // Add all event properties to DynamoDB, avoiding overlaps/duplicates
        Object.keys(event).forEach((key) => {
            // Skip primary key and attributes already explicitly set
            if (key === 'guid' || key === 'workflowStatus' || key === 'timestamp') {
                return;
            }

            // Guard against nested/document path style keys to avoid overlap errors
            if (key.includes('.') || key.includes('[') || key.includes(']')) {
                return;
            }

            const placeholder = `:${key}`;
            // If this attribute was already added, skip
            if (params.UpdateExpression.includes(` ${key} =`) || params.ExpressionAttributeValues[placeholder] !== undefined) {
                return;
            }

            params.UpdateExpression += `, ${key} = ${placeholder}`;
            params.ExpressionAttributeValues[placeholder] = event[key];
        });

        await dynamo.update(params);
        console.log('DynamoDB updated successfully');
    } catch (err) {
        console.error('Error:', err);
        throw err;
    }

    return event;
};