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

const { MediaPackageVod } = require("@aws-sdk/client-mediapackage-vod");
const { LambdaClient, InvokeCommand } = require("@aws-sdk/client-lambda");
const crypto = require('crypto');

const buildArnFromUri = (s3Uri) => {
    const S3_URI_ID = 's3://';

    if (!s3Uri.startsWith(S3_URI_ID)) {
        throw new Error(`Unexpected S3Uri: ${s3Uri}`);
    }

    const source = s3Uri.replace(S3_URI_ID, '');
    return `arn:aws:s3:::${source}`;
};

/**
 * Converts the assets to be advertised behind CloudFront (instead of going directly to MediaPackage). For instance:
 * https://endpoint-id.egress.mediapackage-vod.us-east-1.amazonaws.com/out/v1/asset-id/index.m3u8
 * =>
 * https://distribution-id.cloudfront.net/out/v1/asset-id/index.m3u8
 */
const convertEndpoints = (egressEndpoints, cloudFrontEndpoint) => {
    const url = new URL(process.env.GroupDomainName);
    let updatedEndpoints = {};

    egressEndpoints.forEach(endpoint => {
        const parts = endpoint.PackagingConfigurationId.split('-');
        const config = parts.pop().toUpperCase();

        updatedEndpoints[config] = endpoint.Url.replace(url.hostname, cloudFrontEndpoint);
    });

    return updatedEndpoints;
};

const handler = async (event) => {
    console.log(`REQUEST:: ${JSON.stringify(event, null, 2)}`);

    const mediaPackageVod = new MediaPackageVod({
        region: process.env.AWS_REGION,
        customUserAgent: process.env.SOLUTION_IDENTIFIER
    });
    const randomId = crypto.randomBytes(16).toString('hex').toLowerCase();

    try {
        const params = {
            Id: randomId,
            PackagingGroupId: process.env.GroupId,
            SourceArn: buildArnFromUri(event.hlsPlaylist),
            SourceRoleArn: process.env.MediaPackageVodRole,
            ResourceId: randomId
        };
        params.Tags = {'SolutionId': 'SO0021'};

        console.log(`Ingesting asset:: ${JSON.stringify(params, null, 2)}`);
        const response = await mediaPackageVod.createAsset(params);
        event.mediaPackageResourceId = randomId;
        event.egressEndpoints = convertEndpoints(response.EgressEndpoints, event.cloudFront);
        console.log(`ENDPOINTS:: ${JSON.stringify(event.egressEndpoints, null, 2)}`);
    } catch (err) {
        // Error handling
        console.error('Error creating MediaPackage asset:', err);
        
        const lambda = new LambdaClient({
            region: process.env.AWS_REGION,
            customUserAgent: process.env.SOLUTION_IDENTIFIER
        });

        const errorEvent = {
            ...event,
            error: err.message,
            function: 'media-package-assets'
        };

        try {
            await lambda.send(new InvokeCommand({
                FunctionName: process.env.ErrorHandler,
                Payload: JSON.stringify(errorEvent)
            }));
        } catch (invokeErr) {
            console.error('Error invoking error handler:', invokeErr);
        }
        
        throw err;
    }

    return event;
};

exports.handler = handler;
