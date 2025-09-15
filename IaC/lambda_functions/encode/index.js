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

const { MediaConvert } = require("@aws-sdk/client-mediaconvert");

exports.handler = async (event) => {
	console.log(`REQUEST:: ${JSON.stringify(event, null, 2)}`);

	// Resolve the correct account-specific MediaConvert endpoint
	let endpointToUse = process.env.EndPoint;
	try {
		const mc = new MediaConvert({
			region: process.env.AWS_REGION,
			customUserAgent: process.env.SOLUTION_IDENTIFIER
		});
		const endpoints = await mc.describeEndpoints({});
		const discovered = endpoints && endpoints.Endpoints && endpoints.Endpoints[0] && endpoints.Endpoints[0].Url;
		const isGeneric = typeof endpointToUse === 'string' && /https:\/\/mediaconvert\.[^.]+\.amazonaws\.com/.test(endpointToUse);
		if (discovered && (!endpointToUse || isGeneric)) {
			endpointToUse = discovered;
		}
	} catch (e) {
		console.log("Failed to resolve MediaConvert endpoint via DescribeEndpoints, will use env EndPoint if provided.", e);
	}
	console.log(`MEDIACONVERT_ENDPOINT:: ${endpointToUse}`);

	const mediaconvert = new MediaConvert({
		endpoint: endpointToUse,
		customUserAgent: process.env.SOLUTION_IDENTIFIER
	});

	try {
		const inputPath = `s3://${event.srcBucket}/${event.srcVideo}`;
		
		// Extract filename without extension for folder naming
		const srcVideoPath = event.srcVideo;
		const filename = srcVideoPath.split('/').pop().split('.').slice(0, -1).join('.');
		const sanitizedFilename = filename.replace(/[^a-zA-Z0-9_-]/g, '_'); // Sanitize filename for S3
		
		const outputPath = `s3://${event.destBucket}/vod/${sanitizedFilename}`;

		// Baseline for the job parameters
		let job = {
			JobTemplate: event.jobTemplate,
			Role: process.env.MediaConvertRole,
			UserMetadata: {
				guid: event.guid,
				workflow: event.workflowName
			},
			Settings: {
				Inputs: [{
					AudioSelectors: {
						'Audio Selector 1': {
							Offset: 0,
							DefaultSelection: 'NOT_DEFAULT',
							ProgramSelection: 1
						}
					},
					VideoSelector: {
						ColorSpace: 'FOLLOW',
						Rotate: event.inputRotate
					},
					FilterEnable: 'AUTO',
					PsiControl: 'USE_PSI',
					FilterStrength: 0,
					DeblockFilter: 'DISABLED',
					DenoiseFilter: 'DISABLED',
					TimecodeSource: 'EMBEDDED',
					FileInput: inputPath,
				}],
				OutputGroups: []
			}
		};

		let templateNameTried = event.jobTemplate;
		let tmpl;
		console.log(`TEMPLATE_NAME_TRY:: ${templateNameTried}`);
		try {
			tmpl = await mediaconvert.getJobTemplate({ Name: templateNameTried });
		} catch (e1) {
			if (e1 && e1.name === 'NotFoundException' && typeof templateNameTried === 'string') {
				let altName = templateNameTried;
				if (templateNameTried.includes('_mvod_')) {
					altName = templateNameTried.replace('_mvod_', '_qvbr_');
				} else if (templateNameTried.includes('_qvbr_')) {
					altName = templateNameTried.replace('_qvbr_', '_mvod_');
				}
				if (altName !== templateNameTried) {
					console.log(`TEMPLATE_NAME_ALT_TRY:: ${altName}`);
					try {
						tmpl = await mediaconvert.getJobTemplate({ Name: altName });
						job.JobTemplate = altName;
					} catch (e2) {
						console.error('Alternate JobTemplate also not found.', e2);
						throw e1; // throw original not found
					}
				} else {
					throw e1;
				}
			} else {
				throw e1;
			}
		}
		console.log(`TEMPLATE:: ${JSON.stringify(tmpl, null, 2)}`);

		// Copy output groups from template and update destinations
		tmpl.JobTemplate.Settings.OutputGroups.forEach(group => {
			let outputGroup = JSON.parse(JSON.stringify(group)); // Deep copy
			
			// Update destination paths based on output type
			switch (group.OutputGroupSettings.Type) {
				case 'FILE_GROUP_SETTINGS':
					outputGroup.OutputGroupSettings.FileGroupSettings.Destination = `${outputPath}/mp4/`;
					break;
				case 'HLS_GROUP_SETTINGS':
					outputGroup.OutputGroupSettings.HlsGroupSettings.Destination = `${outputPath}/hls/`;
					break;
				case 'DASH_ISO_GROUP_SETTINGS':
					outputGroup.OutputGroupSettings.DashIsoGroupSettings.Destination = `${outputPath}/dash/`;
					break;
				case 'MS_SMOOTH_GROUP_SETTINGS':
					outputGroup.OutputGroupSettings.MsSmoothGroupSettings.Destination = `${outputPath}/mss/`;
					break;
				case 'CMAF_GROUP_SETTINGS':
					outputGroup.OutputGroupSettings.CmafGroupSettings.Destination = `${outputPath}/cmaf/`;
					break;
			}
			
			job.Settings.OutputGroups.push(outputGroup);
		});

		// Add frame capture if enabled
		if (event.frameCapture) {
			const frameGroup = {
				CustomName: 'Frame Capture',
				Name: 'File Group',
				OutputGroupSettings: {
					Type: 'FILE_GROUP_SETTINGS',
					FileGroupSettings: {
						Destination: `${outputPath}/thumbnails/`
					}
				},
				Outputs: [{
					NameModifier: '_thumb',
					ContainerSettings: {
						Container: 'RAW'
					},
					VideoDescription: {
						ColorMetadata: 'INSERT',
						AfdSignaling: 'NONE',
						Sharpness: 100,
						Height: event.frameCaptureHeight || 720,
						RespondToAfd: 'NONE',
						TimecodeInsertion: 'DISABLED',
						Width: event.frameCaptureWidth || 1280,
						ScalingBehavior: 'DEFAULT',
						AntiAlias: 'ENABLED',
						CodecSettings: {
							FrameCaptureSettings: {
								MaxCaptures: 10000000,
								Quality: 80,
								FramerateDenominator: 5,
								FramerateNumerator: 1
							},
							Codec: 'FRAME_CAPTURE'
						},
						DropFrameTimecode: 'ENABLED'
					}
				}]
			};
			job.Settings.OutputGroups.push(frameGroup);
		}

		//if enabled the TimeCodeConfig needs to be set to ZEROBASED not passthrough
		//https://docs.aws.amazon.com/mediaconvert/latest/ug/job-requirements.html
		if (event.acceleratedTranscoding === 'PREFERRED' || event.acceleratedTranscoding === 'ENABLED') {
			job.AccelerationSettings = {"Mode" : event.acceleratedTranscoding}
			job.Settings.TimecodeConfig = {"Source" : "ZEROBASED"}
			job.Settings.Inputs[0].TimecodeSource = "ZEROBASED"
		}
		job.Tags = {'SolutionId': 'SO0021'};
		
		let data = await mediaconvert.createJob(job);
		event.encodingJob = job;
		event.encodeJobId = data.Job.Id;

		console.log(`JOB:: ${JSON.stringify(data, null, 2)}`);
	} catch (err) {
		console.error('Error:', err);
		throw err;
	}

	return event;
};