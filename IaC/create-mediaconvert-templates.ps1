param(
    [string]$StackName = "vod",
    [string]$EnableMediaPackage = "false",
    [string]$Region = "us-east-1"
)

$endpoint = (aws mediaconvert describe-endpoints --query 'Endpoints[0].Url' --output text --region $Region)

Write-Host "Creating MediaConvert universal CMAF job template..."
Write-Host "Stack Name: $StackName"
Write-Host "Enable MediaPackage: $EnableMediaPackage"
Write-Host "Region: $Region"
Write-Host "MediaConvert Endpoint: $endpoint"

# Create templates based on MediaPackage setting
if ($EnableMediaPackage -eq "true" -or $EnableMediaPackage -eq "Yes") {
    # Create both QVBR and MVOD templates when MediaPackage is enabled
    $templateTypes = @("qvbr", "mvod")
    Write-Host "MediaPackage enabled - creating both QVBR and MVOD templates"
} else {
    # Create only QVBR templates when MediaPackage is disabled
    $templateTypes = @("qvbr")
    Write-Host "MediaPackage disabled - creating only QVBR templates"
}

# Path to the JSON template file
$templateFilePath = Join-Path $PSScriptRoot "templates\universal_cmaf_template.json"

# Create templates for both QVBR and MVOD
foreach ($templateType in $templateTypes) {
    $templateName = "$StackName" + "_Ott_universal_Avc_Aac_16x9_$templateType" + "_no_preset"
    Write-Host "Creating universal CMAF template: $templateName"

    # Check if template file exists
    if (-not (Test-Path $templateFilePath)) {
        Write-Error "Template file not found: $templateFilePath"
        exit 1
    }

    # Read the JSON template
    $templateContent = Get-Content $templateFilePath -Raw | ConvertFrom-Json

    # Update template name and destination
    $templateContent.Name = $templateName
    $templateContent.Description = "Universal adaptive bitrate streaming template for iOS and Android devices - $templateType (CMAF for QVBR, HLS for MVOD)"
    
    # Update destination in the output group settings only
    $destination = "s3://$StackName-destination-bucket/cmaf/"
    $templateContent.Settings.OutputGroups[0].OutputGroupSettings.CmafGroupSettings.Destination = $destination

    # Add tags
    $templateContent | Add-Member -NotePropertyName "Tags" -NotePropertyValue @{
        SolutionId = "SO0021"
        TemplateType = $templateType
        Format = "CMAF"
        Platform = "Universal"
        DeviceSupport = "iOS-Android"
    } -Force

    # Create temporary file for AWS CLI
    $tempFile = [System.IO.Path]::GetTempFileName()
    $templateContent | ConvertTo-Json -Depth 10 | Set-Content $tempFile

    try {
        aws mediaconvert create-job-template --cli-input-json file://$tempFile --endpoint-url $endpoint --region $Region --no-cli-pager
        Write-Host "Successfully created universal CMAF template: $templateName"
    } catch {
        Write-Warning "Template $templateName may already exist or failed to create: $_"
    }

    Remove-Item $tempFile
}

Write-Host "MediaConvert template creation completed"
