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

        // Select appropriate resolution-specific template based on source video resolution
        let encodeProfile = event.srcHeight; // Keep original height for reference
        let selectedTemplate = selectTemplateByResolution(event.srcHeight, event.srcWidth, event);
        
        console.log(`Selected template: ${selectedTemplate} for ${event.srcWidth}x${event.srcHeight} video (prevents upscaling)`);

        event.encodingProfile = encodeProfile;
        event.jobTemplate = selectedTemplate; // Set the job template directly

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

/**
 * Select appropriate MediaConvert template based on source video resolution
 * This prevents upscaling by choosing a template that matches or is lower than the source resolution
 * Uses template names passed from input-validate Lambda function
 */
function selectTemplateByResolution(srcHeight, srcWidth, event) {
    // Get template names from event data (passed from input-validate Lambda)
    const template2160p = event.jobTemplate_2160p;
    const template1080p = event.jobTemplate_1080p;
    const template720p = event.jobTemplate_720p;
    
    // Select template based on source resolution (choose highest resolution that doesn't exceed source)
    if (srcHeight >= 2160 && srcWidth >= 3840) {
        return template2160p;
    } else if (srcHeight >= 1080 && srcWidth >= 1920) {
        return template1080p;
    } else if (srcHeight >= 720 && srcWidth >= 1280) {
        return template720p;
    } else {
        // For lower resolutions, use 720p template (will downscale if needed)
        return template720p;
    }
}