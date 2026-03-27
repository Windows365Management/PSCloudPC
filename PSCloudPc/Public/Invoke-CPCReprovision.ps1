function Invoke-CPCReprovision {
    <#
    .SYNOPSIS
    Reprovision a Cloud PC
    .DESCRIPTION
    The function will reprovision a Cloud PC using the Microsoft Graph v1.0 API.
    Optionally override the OS version (Windows 10 or 11) and the user account type
    (standard user or local administrator) for the reprovisioned Cloud PC.
    .PARAMETER Name
    Enter the Cloud PC display name
    .PARAMETER OsVersion
    Optional. The operating system version to provision. Valid values: 'windows10', 'windows11'.
    When omitted the tenant/policy default is used.
    .PARAMETER UserAccountType
    Optional. The local account type for the user on the reprovisioned Cloud PC.
    Valid values: 'standardUser', 'administrator'.
    When omitted the tenant/policy default is used.
    .EXAMPLE
    Invoke-CPCReprovision -Name "CloudPC01"
    .EXAMPLE
    Invoke-CPCReprovision -Name "CloudPC01" -OsVersion windows11 -UserAccountType standardUser
    .NOTES
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-reprovision
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [parameter(Mandatory = $false)]
        [ValidateSet('windows10', 'windows11')]
        [string]$OsVersion,

        [parameter(Mandatory = $false)]
        [ValidateSet('standardUser', 'administrator')]
        [string]$UserAccountType
    )
    
    begin {
        Get-TokenValidity
        
        $CloudPC = Get-CloudPC -name $Name

        if ($null -eq $CloudPC) {
            Throw "No Cloud PC found with name $Name"
            return
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/reprovision"

        Write-Verbose "URL: $url"
    }

    Process {

        $params = @{}

        if ($PSBoundParameters.ContainsKey('OsVersion')) {
            $params['osVersion'] = $OsVersion
        }

        if ($PSBoundParameters.ContainsKey('UserAccountType')) {
            $params['userAccountType'] = $UserAccountType
        }

        $body = $params | ConvertTo-Json -Depth 5

        if ($PSCmdlet.ShouldProcess($CloudPC.displayName, "Reprovision Cloud PC")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -Body $body -ContentType "application/json"
                Write-Output "Cloud PC $($CloudPC.displayName) reprovision initiated"
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
