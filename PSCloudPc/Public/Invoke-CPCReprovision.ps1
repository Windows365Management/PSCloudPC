function Invoke-CPCReprovision {
    <#
    .SYNOPSIS
    Reprovision a Cloud PC
    .DESCRIPTION
    The function will reprovision a Cloud PC using the Microsoft Graph API.
    Optionally override the OS version (Windows 10 or 11) and the user account type
    (standard user or local administrator) for the reprovisioned Cloud PC.

    Identify the Cloud PC by its managed device name (-Name) or by its id (-CloudPCId).
    -CloudPCId also takes Cloud PC objects from the pipeline, such as the output of
    Get-CloudPC; -OsVersion and -UserAccountType apply to every piped Cloud PC.

    Reprovisioning replaces the Cloud PC, so the command asks for confirmation for each
    Cloud PC. Use -Confirm:$false to skip the prompt in automation. The name must match the
    managed device name of exactly one Cloud PC; otherwise no request is sent.
    The command returns no output when the request is accepted.

    A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
    non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
    with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
    -ErrorVariable and $Error can also hold the underlying Graph errors.
    .PARAMETER Name
    Enter the managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    .PARAMETER OsVersion
    Optional. The operating system version to provision. Valid values: 'windows10', 'windows11'.
    When omitted the tenant/policy default is used.
    .PARAMETER UserAccountType
    Optional. The local account type for the user on the reprovisioned Cloud PC.
    Valid values: 'standardUser', 'administrator'.
    When omitted the tenant/policy default is used.
    .PARAMETER CloudPCId
    The id of the Cloud PC. Accepts pipeline input by property name (id or CloudPCId), for example from Get-CloudPC.
    .EXAMPLE
    Invoke-CPCReprovision -Name "CPC-User-XXXX"
    .EXAMPLE
    Invoke-CPCReprovision -Name "CPC-User-XXXX" -OsVersion windows11 -UserAccountType standardUser
    .EXAMPLE
    Invoke-CPCReprovision -Name "CPC-User-XXXX" -Confirm:$false
    .EXAMPLE
    Invoke-CPCReprovision -CloudPCId "00000000-0000-0000-0000-000000000000" -OsVersion windows11
    # Pipeline: Get-CloudPC | Where-Object { $_.status -eq "failed" } | Invoke-CPCReprovision -WhatIf
    .NOTES
    Required permission: CloudPC.ReadWrite.All (delegated or application).
    POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/reprovision with body { "osVersion": "...", "userAccountType": "..." } (only the values passed)
    https://learn.microsoft.com/graph/api/cloudpc-reprovision?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [parameter(Mandatory = $false)]
        [ValidateSet('windows10', 'windows11')]
        [string]$OsVersion,

        [parameter(Mandatory = $false)]
        [ValidateSet('standardUser', 'administrator')]
        [string]$UserAccountType,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    begin {
        Get-TokenValidity

        $params = @{}

        # ValidateSet ignores case, so send the documented enum values
        if ($PSBoundParameters.ContainsKey('OsVersion')) {
            $params['osVersion'] = (@("windows10", "windows11") -eq $OsVersion)[0]
        }

        if ($PSBoundParameters.ContainsKey('UserAccountType')) {
            $params['userAccountType'] = (@("standardUser", "administrator") -eq $UserAccountType)[0]
        }

        $body = $params | ConvertTo-Json -Depth 5
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -Name $Name
        }
        else {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -CloudPCId $CloudPCId
        }

        # The lookup wrote an error for this Cloud PC; continue with the next pipeline object
        if ($null -eq $CloudPC) {
            return
        }

        $targetName = Get-CPCCloudPCLabel -CloudPC $CloudPC
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/reprovision"

        if ($PSCmdlet.ShouldProcess($targetName, "Reprovision Cloud PC")) {
            Write-Verbose "Request: POST $url"
            try {
                $null = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -Body $body -ContentType "application/json" -ErrorAction Stop
                Write-Verbose "Reprovision requested for Cloud PC $targetName"
            }
            catch {
                Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Reprovision" -CloudPC $CloudPC
                return
            }
        }
    }
}
