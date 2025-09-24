# Create-MediaPackageConfiguration.ps1
# PowerShell script to create MediaPackage VOD configuration
# Replaces CloudFormation custom resource functionality

param(
    [Parameter(Mandatory=$true)]
    [string]$StackName,
    
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationBucketArn,
    
    [Parameter(Mandatory=$false)]
    [string]$CloudFrontDistributionId = ""
)

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Initialize AWS SDK
try {
    Import-Module AWSPowerShell -ErrorAction Stop
} catch {
    Write-Error "AWS PowerShell module not found. Please install it using: Install-Module -Name AWSPowerShell"
    exit 1
}

$groupId = "${StackName}-packaging-group"

Write-Host "Creating MediaPackage VOD configuration for stack: $StackName"

try {
    # Create packaging group
    Write-Host "Creating packaging group: $groupId"
    try {
        New-MPVPackagingGroup -Id $groupId -Tags @{
            "SolutionId" = "SO0021"
            "StackName" = $StackName
        }
        Write-Host "Successfully created packaging group: $groupId"
    } catch {
        if ($_.Exception.Message -like "*UnprocessableEntityException*") {
            Write-Warning "Packaging group $groupId already exists"
        } else {
            throw
        }
    }
    
    # Create packaging configurations - HLS, DASH, MSS, and CMAF
    $configTypes = @('HLS', 'DASH', 'MSS', 'CMAF')
    $createdConfigs = @()
    
    foreach ($configType in $configTypes) {
        $configId = "${StackName}-$($configType.ToLower())-packaging-config"
        
        try {
            Write-Host "Creating packaging configuration: $configId"
            $config = Get-PackagingConfiguration -ConfigType $configType -ConfigId $configId -GroupId $groupId -StackName $StackName
            New-MPVPackagingConfiguration @config
            $createdConfigs += $configId
            Write-Host "Successfully created packaging configuration: $configId"
        } catch {
            if ($_.Exception.Message -like "*UnprocessableEntityException*") {
                Write-Warning "Packaging configuration $configId already exists"
                $createdConfigs += $configId
            } else {
                Write-Error "Error creating packaging configuration $configId : $_"
                throw
            }
        }
    }
    
    # Get packaging group details
    $groupDetails = Get-MPVPackagingGroup -Id $groupId
    
    Write-Host "MediaPackage VOD configuration completed successfully!"
    Write-Host "Packaging Group ID: $groupId"
    Write-Host "Domain Name: $($groupDetails.DomainName)"
    Write-Host "Created configurations: $($createdConfigs -join ', ')"
    
    # Update CloudFront distribution if specified
    if ($CloudFrontDistributionId) {
        Write-Host "Updating CloudFront distribution: $CloudFrontDistributionId with MediaPackage domain: $($groupDetails.DomainName)"
        # Note: CloudFront distribution update would be implemented here if needed
        # This is a placeholder for CloudFront integration
    }
    
} catch {
    Write-Error "Failed to create MediaPackage VOD configuration: $_"
    exit 1
}

# Function to generate packaging configuration based on type
function Get-PackagingConfiguration {
    param(
        [string]$ConfigType,
        [string]$ConfigId,
        [string]$GroupId,
        [string]$StackName
    )
    
    $baseConfig = @{
        Id = $ConfigId
        PackagingGroupId = $GroupId
        Tags = @{
            "SolutionId" = "SO0021"
            "StackName" = $StackName
            "Format" = $ConfigType
        }
    }
    
    switch ($ConfigType.ToUpper()) {
        'HLS' {
            $baseConfig.HlsPackage = @{
                HlsManifests = @(
                    @{
                        AdMarkers = "NONE"
                        IncludeIframeOnlyStream = $false
                        ManifestName = "index"
                        ProgramDateTimeIntervalSeconds = 0
                        RepeatExtXKey = $false
                        StreamSelection = @{
                            MaxVideoBitsPerSecond = 2147483647
                            MinVideoBitsPerSecond = 0
                            StreamOrder = "ORIGINAL"
                        }
                    }
                )
                SegmentDurationSeconds = 10
                UseAudioRenditionGroup = $false
            }
        }
        
        'DASH' {
            $baseConfig.DashPackage = @{
                DashManifests = @(
                    @{
                        ManifestName = "index"
                        StreamSelection = @{
                            MaxVideoBitsPerSecond = 2147483647
                            MinVideoBitsPerSecond = 0
                            StreamOrder = "ORIGINAL"
                        }
                    }
                )
                SegmentDurationSeconds = 10
            }
        }
        
        'MSS' {
            $baseConfig.MssPackage = @{
                MssManifests = @(
                    @{
                        ManifestName = "index"
                        StreamSelection = @{
                            MaxVideoBitsPerSecond = 2147483647
                            MinVideoBitsPerSecond = 0
                            StreamOrder = "ORIGINAL"
                        }
                    }
                )
                SegmentDurationSeconds = 10
            }
        }
        
        'CMAF' {
            $baseConfig.CmafPackage = @{
                HlsManifests = @(
                    @{
                        AdMarkers = "NONE"
                        IncludeIframeOnlyStream = $false
                        ManifestName = "index"
                        ProgramDateTimeIntervalSeconds = 0
                        RepeatExtXKey = $false
                        StreamSelection = @{
                            MaxVideoBitsPerSecond = 2147483647
                            MinVideoBitsPerSecond = 0
                            StreamOrder = "ORIGINAL"
                        }
                    }
                )
                SegmentDurationSeconds = 10
            }
        }
        
        default {
            throw "Unsupported packaging configuration type: $ConfigType"
        }
    }
    
    return $baseConfig
}

Write-Host "MediaPackage VOD configuration script completed!"
