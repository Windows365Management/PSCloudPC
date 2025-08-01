#Requires -Module Microsoft.PowerShell.PlatyPS
#Requires -Version 7.0
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string] $ModuleName = "PSCloudPC",

    [Parameter(Mandatory = $false)]
    [string] $ModulePath = (Join-Path (Get-Item $PSScriptRoot).Parent $ModuleName),

    [Parameter(Mandatory = $false)]
    [string] $HelpFolder = (Join-Path (Split-Path $ModulePath -Parent) 'Docs'),

    [Parameter(Mandatory = $false)]
    [string] $Locale = 'en-US'
)

Write-Verbose $HelpFolder -Verbose
Write-Verbose $ModulePath -Verbose

$i = Import-Module $modulePath -Force -PassThru
# TODO: Use Update-MarkdownCommandHelp to reflect changes and copy over the updated content
New-MarkdownCommandHelp -ModuleInfo $i -WithModulePage -OutputFolder $HelpFolder -Locale 'en-US' -Force
$markdownFiles = Measure-PlatyPSMarkdown -Path ($HelpFolder + [System.IO.Path]::DirectorySeparatorChar + "*.md")
$markdownFiles | Where-Object FileType -match 'CommandHelp' | Import-MarkdownCommandHelp -Path { $_.FilePath } | Export-MamlCommandHelp -OutputFolder $HelpFolder -Force

# Move all files to the root of docs
$outputFolder = Join-Path $HelpFolder $ModuleName
$files = Get-ChildItem -Path $outputFolder -Filter "*.md" -Exclude "$ModuleName.md" -Recurse
foreach ($file in $files)
{
    # Copy the item first because mkdocs doesn't support traversing paths or in the root
    Copy-Item -Path $file -Destination (Join-Path $HelpFolder 'docs' 'cmdlets') -Force
    Move-Item -Path $file -Destination $HelpFolder -Force
}

# Keep the external help file in the module build instead of Markdown files to reduce package size
Move-Item -Path (Join-Path $outputFolder "$ModuleName-Help.xml") -Destination (Join-Path $ModulePath $Locale) -Force

# The module page file "can" be your index
# TODO: Maybe use Import-MamlHelp afterwards with a static.txt to load in additional content
# Move-Item -Path (Join-Path $outputFolder "$ModuleName.md") -Destination (Join-Path (Split-Path $outputFolder -Parent) 'docs')

Remove-Item $outputFolder -Force -ErrorAction SilentlyContinue -Recurse