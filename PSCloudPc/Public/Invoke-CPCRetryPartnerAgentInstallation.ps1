function Invoke-CPCRetryPartnerAgentInstallation {
    <#
    .SYNOPSIS
    Retries installation of partner agents that failed to install on a Cloud PC
    .DESCRIPTION
    The function triggers the retryPartnerAgentInstallation action on a specific Cloud PC.
    When third-party partner agents (such as monitoring or security agents) fail to install
    during provisioning, this action instructs the service to retry the failed agent
    installations without requiring a full reprovision.

    This is useful when a Cloud PC enters a warning or degraded state because a partner
    agent could not be installed, and you want to attempt remediation before resorting
    to reprovisioning.

    The action returns 204 No Content on success. You can identify the target Cloud PC
    by its managed device name (default) or by providing the Cloud PC object ID directly
    via -CloudPCId.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name.
    .EXAMPLE
    Invoke-CPCRetryPartnerAgentInstallation -Name "CPC-User-XXXX"
    .EXAMPLE
    Invoke-CPCRetryPartnerAgentInstallation -CloudPCId "4b5ad5e0-6a0b-4ffc-818d-36bb23cf4dbd"
    .EXAMPLE
    Invoke-CPCRetryPartnerAgentInstallation -Name "CPC-User-XXXX" -WhatIf
    .NOTES
    Requires CloudPC.ReadWrite.All permission (delegated or application).
    This function uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-retrypartneragentinstallation
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    Begin {
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

        # retryPartnerAgentInstallation is a beta-only API
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$targetId/retryPartnerAgentInstallation"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Retrying partner agent installation on Cloud PC '$targetName' (id: $targetId)"

        if ($PSCmdlet.ShouldProcess($targetName, "Retry partner agent installation on Cloud PC")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json"
                Write-Output "Partner agent installation retry triggered for Cloud PC '$targetName'"
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
