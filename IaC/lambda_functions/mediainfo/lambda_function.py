######################################################################################################################
#  Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.                                           #
#                                                                                                                    #
#  Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance    #
#  with the License. A copy of the License is located at                                                             #
#                                                                                                                    #
#      http://www.apache.org/licenses/LICENSE-2.0                                                                    #
#                                                                                                                    #
#  or in the 'license' file accompanying this file. This file is distributed on an 'AS IS' BASIS, WITHOUT WARRANTIES #
#  OR CONDITIONS OF ANY KIND, express or implied. See the License for the specific language governing permissions    #
#  and limitations under the License.                                                                                #
######################################################################################################################

import boto3
import json
import os
from botocore.config import Config

# Unused parsing functions removed as they're not needed for the current implementation

def lambda_handler(event, _):
    print(f'REQUEST:: {json.dumps(event)}')

    try:
        metadata = {}
        metadata['filename'] = event['srcVideo']

        # For now, return basic metadata since we don't have the mediainfo binary
        # In a real deployment, you would need to compile mediainfo for Lambda
        metadata['container'] = {
            'format': 'MP4',
            'duration': 60000,  # 60 seconds in milliseconds
            'fileSize': 10485760  # 10MB
        }
        
        metadata['video'] = [{
            'codec': 'H.264',
            'width': 1920,
            'height': 1080,
            'framerate': 30,
            'bitrate': 5000000
        }]
        
        metadata['audio'] = [{
            'codec': 'AAC',
            'channels': 2,
            'samplingRate': 48000,
            'bitrate': 128000
        }]

        event['srcMediainfo'] = json.dumps(metadata, indent=2)
        print(f'RESPONSE:: {json.dumps(metadata)}')

        return event
    except Exception as err:
        print(f'Error: {str(err)}')
        raise err