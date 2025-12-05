[CmdletBinding()]
param (
    [Parameter()]
    [string]$PS_GALLERY_KEY
)
Install-Module -Name MSAL.PS -Force -Scope CurrentUser
$env:ProjectName = "PSCloudPC"
Publish-Module -Path './Src' -NuGetApiKey $PS_GALLERY_KEY
write-host "Module $env:ProjectName published"
