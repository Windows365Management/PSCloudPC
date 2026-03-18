[CmdletBinding()]
param (
    [Parameter()]
    [string]$PS_GALLERY_KEY
)

# Install required module
Install-Module -Name MSAL.PS -Force -Scope CurrentUser

# Set project name
$env:ProjectName = "PSCloudPC"

# Build the correct module path relative to the Publish directory
# When running from the repo root, the module manifest is at ./Src/PSCloudPC.psd1
$ModulePath = Join-Path (Split-Path -Parent $PSScriptRoot) -ChildPath "Src"

# Verify the module path exists
if (-not (Test-Path $ModulePath)) {
    throw "Module path not found: $ModulePath"
}

#Test manifest
Test-ModuleManifest -Path ./Src/PSCloudPC.psd1

# Publish the module
Publish-Module -Path $ModulePath -NuGetApiKey $PS_GALLERY_KEY -ErrorAction Stop

Write-Host "Module $env:ProjectName published successfully to PowerShell Gallery"
