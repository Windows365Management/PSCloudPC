function Invoke-CPCChangeUserAccountType {
    <#
    .SYNOPSIS
    Changes the local account type of the user on a Cloud PC
    .DESCRIPTION
    The function will change the user account type on a specific Cloud PC between
    standard user and local administrator using the Microsoft Graph beta API.
    Use this to elevate a user to local admin for troubleshooting or to demote
    an administrator back to a standard user for compliance reasons.
    .PARAMETER Name
    Enter the display name of the Cloud PC
    .PARAMETER UserAccountType
    The account type to set for the user on the Cloud PC.
    Valid values: 'standardUser', 'administrator'.
    .EXAMPLE
    Invoke-CPCChangeUserAccountType -Name "CloudPC01" -UserAccountType administrator
    .EXAMPLE
    Invoke-CPCChangeUserAccountType -Name "CloudPC01" -UserAccountType standardUser
    .NOTES
    Requires CloudPC.ReadWrite.All permission (delegated or application).
    This action uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-changeuseraccounttype
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('standardUser', 'administrator')]
        [string]$UserAccountType
    )

    begin {
        Get-TokenValidity

        $CloudPC = Get-CloudPC -Name $Name

        if ($null -eq $CloudPC) {
            Throw "No Cloud PC found with name '$Name'"
            return
        }

        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/changeUserAccountType"

        Write-Verbose "URL: $url"
    }

    Process {
        $params = @{
            userAccountType = $UserAccountType
        } | ConvertTo-Json -Depth 10

        Write-Verbose "Changing user account type on Cloud PC '$($CloudPC.displayName)' (id: $($CloudPC.id)) to '$UserAccountType'"

        if ($PSCmdlet.ShouldProcess($CloudPC.displayName, "Change user account type to '$UserAccountType'")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -Body $params -ContentType "application/json"
                Write-Output "Cloud PC '$($CloudPC.displayName)' user account type changed to '$UserAccountType'"
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
