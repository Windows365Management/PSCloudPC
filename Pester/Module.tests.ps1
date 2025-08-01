$module = 'PSCloudPC'
Describe "$module Global module tests" {
    Context 'Module Setup' {
        BeforeAll {
            $modulePath = Join-Path -Path (Join-Path ".././" -ChildPath "PSCloudPC") -ChildPath "source"
            $binaryFile = "PSCloudPC.psm1"
            $manifestFile = "PSCloudPC.psd1"
            $moduleContent = Import-PowerShellDataFile (Join-Path -Path $modulePath -ChildPath $manifestFile)
        }

        It "$module has the root module $module.psm1" {
            $modulePath | Should -Exist
        }

        It "$module has the a manifest file of $module.psm1" {
            (Join-Path -Path $modulePath -ChildPath $binaryFile) | Should -Exist
            (Join-Path -Path $modulePath -ChildPath $manifestFile) | Should -Exist
        }

        It "$module folder has functions folder" {
            (Join-Path -Path $modulePath -ChildPath "Public") | Should -Exist
        }

        It "$module folder has private functions folder" {
            (Join-Path -Path $modulePath -ChildPath "Private") | Should -Exist
        }

        It "$module root module should be $binaryFile in $manifestFile" {
           $binaryFile -eq $moduleContent.RootModule | Should -Be $true
        }

        It "$module should have a semver version" {
            $moduleContent.ModuleVersion -match "^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+))?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+))?$" | Should -Be $true
        }
#        It "$module version should be greater than PSGallery" {
#            $galleryVersion = (Find-Module -Name PSCloudPC -Repository PSGallery).Version
#            [version]$moduleContent.ModuleVersion | Should -BeGreaterThan ([version]$galleryVersion)
#        }

        It "$module project URL should reachable" {
            try {
                Invoke-WebRequest -Uri $moduleContent.PrivateData.PSData.ProjectUri -UseBasicParsing -DisableKeepAlive -method Head | Out-Null
                $exists = $true
            }
            catch {
                $exists = $false
            }
            $exists | Should -Be $true
        }

        It "$module is valid PowerShell code" {
            $psFile = Get-Content -Path (Join-Path -Path $modulePath -ChildPath $binaryFile) -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }
}
