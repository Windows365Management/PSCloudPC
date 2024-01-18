[CmdletBinding()]
param (
    [Parameter()]
    [string]$PS_GALLERY_KEY
)
$env:ProjectName = "PSCloudPC"
        Publish-Module -Path (Join-Path ".././PSCloudPC" -ChildPath $env:ProjectName) -NuGetApiKey $PS_GALLERY_KEY
        write-host "Module $env:ProjectName published"
