function Invoke-CPCChangeUserAccountType {
    <#
    .SYNOPSIS
    Changes the local account type of the user on a Cloud PC
    .DESCRIPTION
    The function will change the user account type on a specific Cloud PC between
    standard user and local administrator using the Microsoft Graph beta API.
    Use this to elevate a user to local admin for troubleshooting or to demote
    an administrator back to a standard user for compliance reasons.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name.
    .PARAMETER UserAccountType
    The account type to set for the user on the Cloud PC.
    Valid values: 'standardUser', 'administrator'.
    .EXAMPLE
    Invoke-CPCChangeUserAccountType -Name "CPC-User-XXXX" -UserAccountType administrator
    .EXAMPLE
    Invoke-CPCChangeUserAccountType -CloudPCId "4b5ad5e0-6a0b-4ffc-818d-36bb23cf4dbd" -UserAccountType standardUser
    .EXAMPLE
    Invoke-CPCChangeUserAccountType -Name "CPC-User-XXXX" -UserAccountType administrator -WhatIf
    .NOTES
    Requires CloudPC.ReadWrite.All permission (delegated or application).
    This action uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-changeuseraccounttype
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('standardUser', 'administrator')]
        [string]$UserAccountType
    )

    begin {
        Get-TokenValidity

        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $CloudPC = Get-CloudPC -Name $Name

            if ($null -eq $CloudPC -or @($CloudPC).Count -eq 0) {
                Throw "No Cloud PC found with name '$Name'. Use Get-CloudPC to verify the managed device name."
            }

            # Take the first result in case the filter returns multiple
            $CloudPC = @($CloudPC)[0]
            $targetId = $CloudPC.id
            $targetName = $CloudPC.displayName
        }
        else {
            $targetId = $CloudPCId
            $targetName = $CloudPCId
        }

        # changeUserAccountType is beta-only; no v1.0 equivalent exists
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$targetId/changeUserAccountType"

        Write-Verbose "URL: $url"
    }

    Process {
        $body = @{
            userAccountType = $UserAccountType
        } | ConvertTo-Json -Depth 10

        Write-Verbose "Changing user account type on Cloud PC '$targetName' (id: $targetId) to '$UserAccountType'"

        if ($PSCmdlet.ShouldProcess($targetName, "Change user account type to '$UserAccountType'")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -Body $body -ContentType "application/json"
                Write-Output "Cloud PC '$targetName' user account type changed to '$UserAccountType'"
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
