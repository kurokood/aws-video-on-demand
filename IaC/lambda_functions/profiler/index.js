/*********************************************************************************************************************
 *  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.                                           *
 *                                                                                                                    *
 *  Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance    *
 *  with the License. A copy of the License is located at                                                             *
 *                                                                                                                    *
 *      http://www.apache.org/licenses/LICENSE-2.0                                                                    *
 *                                                                                                                    *
 *  or in the 'license' file accompanying this file. This file is distributed on an 'AS IS' BASIS, WITHOUT WARRANTIES *
 *  OR CONDITIONS OF ANY KIND, express or implied. See the License for the specific language governing permissions    *
 *  and limitations under the License.                                                                                *
 *********************************************************************************************************************/

const { DynamoDBDocument } = require("@aws-sdk/lib-dynamodb");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");

exports.handler = async (event) => {
    console.log(`REQUEST:: ${JSON.stringify(event, null, 2)}`);

    const dynamo = DynamoDBDocument.from(new DynamoDBClient({ 
        region: process.env.AWS_REGION,
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    }));

    try {
        // Download DynamoDB data for the source file:
        let params = {
            TableName: process.env.DynamoDBTable,
            Key: {
                guid: event.guid
            }
        };

        let data = await dynamo.get(params);

        if (data.Item) {
            Object.keys(data.Item).forEach(key => {
                event[key] = data.Item[key];
            });
        } else {
            console.log('No item found in DynamoDB for guid:', event.guid);
        }

        let mediaInfo = JSON.parse(event.srcMediainfo);
        event.srcHeight = mediaInfo.video[0].height;
        event.srcWidth = mediaInfo.video[0].width;
        
        console.log(`Source video resolution: ${event.srcWidth}x${event.srcHeight}`);

        // Use universal template for all video resolutions (adaptive bitrate with no upscaling)
        let encodeProfile = event.srcHeight; // Keep original height for reference
        let selectedTemplate = process.env.MediaConvert_Template_Universal;
        
        console.log(`Using universal adaptive bitrate template for ${event.srcWidth}x${event.srcHeight} video (prevents upscaling)`);

        event.encodingProfile = encodeProfile;

        if (event.frameCapture) {
            // Use the source video dimensions for frame capture
            event.frameCaptureHeight = event.srcHeight;
            event.frameCaptureWidth = event.srcWidth;
        }

        // Update:: added support to pass in a custom encoding Template instead of using the
        // solution defaults
        if (!event.jobTemplate) {
            event.jobTemplate = selectedTemplate;
            console.log(`Chosen template:: ${event.jobTemplate}`);

            event.isCustomTemplate = false;
        } else {
            event.isCustomTemplate = true;
        }
    } catch (err) {
        console.error('Error:', err);
        throw err;
    }

    console.log(`RESPONSE:: ${JSON.stringify(event, null, 2)}`);
    return event;
};