$modulePath = Join-Path -Path (Join-Path ".././" -ChildPath "PSCloudPC") -ChildPath "source"
$psFiles = Get-ChildItem -Path (Join-Path -Path $modulePath -ChildPath "Public")

Describe "Analyze code" -ForEach @(
    foreach ($file in $psFiles) {
        @{
            file        = $file
            fileName    = $file.Name
            fileBase    = $file.BaseName
            content     = Get-Content -Path $file
            helpInfo    = Get-Help $file.BaseName
            IgnoreRules = @('PSUseApprovedVerbs')
            fileobj     = $file
        }
    }
) {
    It "<fileName> should exist" {
        Test-Path $file | Should -Be $true
    }

    It "<fileName> should have content" {
        $file.Length | Should -BeGreaterThan 0
    }

    It "<fileName> should have help block" {
        $file | Should -FileContentMatch '<#'
        $file | Should -FileContentMatch '#>'
    }

    It "<fileName> should have a SYNOPSIS section in the help block" {
        $file | Should -FileContentMatch '.SYNOPSIS'
    }

    It "<fileName> should have a DESCRIPTION section in the help block" {
        $file | Should -FileContentMatch '.DESCRIPTION'
    }

    It "<fileName> should have a EXAMPLE section in the help block" {
        $file | Should -FileContentMatch '.EXAMPLE'
    }
    It "<example> should start with <filebase> or contain | <filebase>" -TestCases @(
        foreach ($example in $helpInfo.examples.example) {
            @{
                example = [string]$example.title.Replace("-", $null)
                code    = [string]$example.code
            }
        }
    ) {
        (($code.StartsWith($fileBase)) -or ($code.Contains("| {0}" -f $fileBase) )) | Should -Be $true -Because "Provide good examples"
    }
    It "<filename> line <linenr> uses the # sign correctly" -TestCases @(
        $correctUse = '^#Requires', '^<#', '^#>', '^#region', '^#endregion', '^# ', '##vso\[task.'
        $comments = (Select-String -Path $file -Pattern '#')
        ForEach ($comment in $comments) {
            $correct = ForEach ($use in $correctUse) {
                ($comment.line.trim() -match $use)
            }
            if ($correct -notcontains $true) {
                $correctComment = $false
            }
            else {
                $correctComment = $true
            }
            @{
                linenr         = $comment.LineNumber
                line           = $comment.Line
                correctUse     = $correctUse
                correctComment = $correctComment
            }
        }
    ) {
        $correctComment | should -be $true -because "comment $line should match $($correctUse -join ',' | Out-String)"
    }

    It "<fileName> should be an advanced function" {
        $file | Should -FileContentMatch 'function'
        $file | Should -FileContentMatch 'cmdletbinding'
        $file | Should -FileContentMatch 'param'
    }

    It "<fileName> should contain Write-Verbose blocks" {
        $file | Should -FileContentMatch 'Write-Verbose'
    }

    It "<fileName> should not contain Write-Host" {
        $file | Should -Not -FileContentMatch 'Write-Host'
    }

    It "<fileName> should not contain return in functions" {
        $file | Should -Not -FileContentMatch 'return `$'
    }

    #    It "<fileName> should have an Get-TokenValidity" {
    #       ($content | Select-String -Pattern 'Get-TokenValidity') | Should -Be $true
    #    }

    It "<fileName> function start with function name and should be $($file.BaseName) " {
        $content[0] -match "function $($file.BaseName) {" | Should -Be $true
    }

    It "<fileBase> function should be available in module" {
        try {
            Get-Command $fileBase -Module "PSCloudPC"
        }
        catch {
            "$fileBase is not found in commmand list"
        }
    }
    It "Uses PascalCase for Parameter <name>" -TestCases @(
        foreach ($parameter in $helpInfo.parameters.parameter) {
            @{
                name = [string]$parameter.name
            }
        }
    ) {
        $name | Should -MatchExactly '^[A-Z].*' -Because "PascalCasing"
    }
}