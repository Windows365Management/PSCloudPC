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

    You can identify the target Cloud PC by its managed device name (default) or by
    providing the Cloud PC object ID directly via -CloudPCId. -CloudPCId also takes Cloud PC
    objects from the pipeline, such as the output of Get-CloudPC. The name must match exactly
    one Cloud PC; otherwise no request is sent. The command returns no output when the
    request is accepted.

    A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
    non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
    with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
    -ErrorVariable and $Error can also hold the underlying Graph errors.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name. Accepts pipeline input by property name (id or
    CloudPCId), for example from Get-CloudPC.
    .EXAMPLE
    Invoke-CPCRetryPartnerAgentInstallation -Name "CPC-User-XXXX"
    .EXAMPLE
    Invoke-CPCRetryPartnerAgentInstallation -CloudPCId "00000000-0000-0000-0000-000000000000"
    # Pipeline: Get-CloudPC | Where-Object { $_.status -eq "provisionedWithWarnings" } | Invoke-CPCRetryPartnerAgentInstallation
    .EXAMPLE
    Invoke-CPCRetryPartnerAgentInstallation -Name "CPC-User-XXXX" -WhatIf
    .NOTES
    Required permission: CloudPC.ReadWrite.All (delegated or application).
    This function uses the Microsoft Graph beta endpoint:
    POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/retryPartnerAgentInstallation (no request body)
    https://learn.microsoft.com/graph/api/cloudpc-retrypartneragentinstallation?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    Begin {
        Get-TokenValidity
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
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/retryPartnerAgentInstallation"

        if ($PSCmdlet.ShouldProcess($targetName, "Retry partner agent installation on Cloud PC")) {
            Write-Verbose "Request: POST $url"
            try {
                $null = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ErrorAction Stop
                Write-Verbose "Partner agent installation retry requested for Cloud PC $targetName"
            }
            catch {
                Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Retry partner agent installation" -CloudPC $CloudPC
                return
            }
        }
    }
}
