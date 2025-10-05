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

import json
import re
import os

def lambda_handler(event, context):
    """
    MediaInfo Lambda Function - Analyzes video metadata
    
    This function extracts video metadata and determines video dimensions.
    In a production environment, this would use the MediaInfo binary.
    For simplicity, it uses filename-based detection with fallbacks.
    """
    print(f'REQUEST:: {json.dumps(event)}')
    
    try:
        if 'srcVideo' not in event:
            raise ValueError("srcVideo is required in the event")
        
        filename = event['srcVideo']
        print(f'Analyzing video: {filename}')
        
        # Extract dimensions from filename with improved pattern matching
        width, height = detect_resolution_from_filename(filename)
        
        # Set the source video dimensions in the event
        event['srcWidth'] = width
        event['srcHeight'] = height
        
        # Create comprehensive metadata for compatibility
        metadata = create_video_metadata(filename, width, height)
        
        event['srcMediainfo'] = json.dumps(metadata, indent=2)
        print(f'Detected video dimensions: {width}x{height}')
        
        return event
        
    except Exception as err:
        print(f'Error analyzing video metadata: {str(err)}')
        # Fallback to 720p if analysis fails
        event['srcWidth'] = 1280
        event['srcHeight'] = 720
        
        # Create fallback metadata
        fallback_metadata = create_video_metadata(
            event.get('srcVideo', 'unknown'), 1280, 720
        )
        event['srcMediainfo'] = json.dumps(fallback_metadata, indent=2)
        
        print('Using fallback dimensions: 1280x720')
        return event

def detect_resolution_from_filename(filename):
    """
    Detect video resolution from filename patterns
    
    Args:
        filename (str): The video filename
        
    Returns:
        tuple: (width, height) dimensions
    """
    filename_lower = filename.lower()
    
    # Common resolution patterns
    resolution_patterns = [
        (r'4k|2160p|uhd', 3840, 2160),
        (r'1440p|2k', 2560, 1440),
        (r'1080p|fhd|fullhd', 1920, 1080),
        (r'720p|hd', 1280, 720),
        (r'480p|sd', 854, 480),
        (r'360p', 640, 360),
    ]
    
    # Try to match resolution patterns
    for pattern, width, height in resolution_patterns:
        if re.search(pattern, filename_lower):
            return width, height
    
    # Try to extract dimensions from patterns like "1920x1080"
    dimension_match = re.search(r'(\d{3,4})x(\d{3,4})', filename_lower)
    if dimension_match:
        width = int(dimension_match.group(1))
        height = int(dimension_match.group(2))
        return width, height
    
    # Default to 720p for unknown patterns
    print(f'No resolution pattern found in filename: {filename}. Using default 720p')
    return 1280, 720

def create_video_metadata(filename, width, height):
    """
    Create comprehensive video metadata structure
    
    Args:
        filename (str): The video filename
        width (int): Video width
        height (int): Video height
        
    Returns:
        dict: Complete metadata structure
    """
    # Determine video profile based on resolution
    if height >= 2160:
        profile = 'UHD'
        bitrate = 25000000  # 25 Mbps for 4K
    elif height >= 1080:
        profile = 'Full HD'
        bitrate = 8000000   # 8 Mbps for 1080p
    elif height >= 720:
        profile = 'HD'
        bitrate = 5000000   # 5 Mbps for 720p
    else:
        profile = 'SD'
        bitrate = 2500000   # 2.5 Mbps for SD
    
    # Calculate estimated duration and file size (placeholder values)
    estimated_duration = 300000  # 5 minutes in milliseconds
    estimated_file_size = int((bitrate * estimated_duration / 1000) / 8)  # Rough estimate
    
    return {
        'filename': filename,
        'profile': profile,
        'container': {
            'format': 'MP4',
            'duration': estimated_duration,
            'fileSize': estimated_file_size
        },
        'video': [{
            'codec': 'H.264',
            'width': width,
            'height': height,
            'aspectRatio': f'{width}:{height}',
            'framerate': 30.0,
            'bitrate': bitrate,
            'profile': 'High',
            'level': '4.0'
        }],
        'audio': [{
            'codec': 'AAC',
            'channels': 2,
            'samplingRate': 48000,
            'bitrate': 128000,
            'channelLayout': 'stereo'
        }]
    }