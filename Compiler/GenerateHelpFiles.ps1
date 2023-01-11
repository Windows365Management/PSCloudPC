$moduleName = "PSCloudPC"
[string]$helpFolder = Join-Path -Path (Join-Path ".././" -ChildPath "PSCloudPC") -ChildPath "Docs"
$modulePath = Join-Path -Path (Join-Path ".././" -ChildPath "PSCloudPC") -ChildPath $moduleName
[string]$output = Join-Path (Get-Location) "/Docs"
[cultureinfo]$HelpCultureInfo = 'en-US'

Import-Module -Force $modulePath
Update-MarkdownHelpModule -Path $helpFolder
New-MarkdownHelp -Module $moduleName -OutputFolder $helpFolder -Force
New-ExternalHelp -Path $HelpFolder -OutputPath "$modulePath\$HelpCultureInfo" -Force