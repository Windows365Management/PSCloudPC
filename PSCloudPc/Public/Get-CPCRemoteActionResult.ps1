function Get-CPCRemoteActionResult {
    <#
    .SYNOPSIS
    Retrieves the remote action results for a specific Cloud PC
    .DESCRIPTION
    The function retrieves the results of remote actions (such as reboot, reprovision,
    resize, restore, rename, and troubleshoot) that have been executed on a specific
    Cloud PC using the Microsoft Graph beta API.

    Each result includes the action name, its current state (pending, canceled, active,
    done, failed, or notSupported), timestamps for when the action was initiated and
    last updated, and additional status details.

    This is useful for verifying that a triggered action completed successfully,
    diagnosing failed remote actions, and auditing the history of operations on a
    Cloud PC without relying on audit events.

    You can identify the target Cloud PC by its managed device name (default) or by
    providing the Cloud PC object ID directly via -CloudPCId. -CloudPCId also takes Cloud PC
    objects from the pipeline, such as the output of Get-CloudPC. The name must match
    exactly one Cloud PC. When a Cloud PC has no results, nothing is returned for it.

    Returns one object per remote action with CloudPCName, CloudPCId, actionName, actionState,
    startDateTime, lastUpdatedDateTime, managedDeviceId and statusDetails.
    CloudPCName is the managed device name (the Intune device name) that -Name expects. It is
    empty while the Cloud PC is still provisioning and for Windows 365 Business Cloud PCs;
    use the id (CloudPCId) for those.

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
    Get-CPCRemoteActionResult -Name "CPC-User-XXXX"
    .EXAMPLE
    Get-CPCRemoteActionResult -CloudPCId "00000000-0000-0000-0000-000000000000"
    # Pipeline: Get-CloudPC | Get-CPCRemoteActionResult | Where-Object { $_.actionState -eq "active" }
    .EXAMPLE
    Get-CPCRemoteActionResult -Name "CPC-User-XXXX" | Where-Object { $_.actionState -eq 'failed' }
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    This function uses the Microsoft Graph beta endpoint:
    GET /deviceManagement/virtualEndpoint/cloudPCs/{id}/retrieveCloudPcRemoteActionResults
    https://learn.microsoft.com/graph/api/cloudpc-retrievecloudpcremoteactionresults?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
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

        $targetId = $CloudPC.id
        $targetName = Get-CPCCloudPCName -CloudPC $CloudPC

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$targetId/retrieveCloudPcRemoteActionResults"
        Write-Verbose "Request: GET $url"

        try {
            $result = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method GET -ContentType "application/json" -ErrorAction Stop
        }
        catch {
            Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Get remote action results" -CloudPC $CloudPC
            return
        }

        if ($null -eq $result -or $null -eq $result.value -or @($result.value).Count -eq 0) {
            Write-Verbose "No remote action results found for Cloud PC $(Get-CPCCloudPCLabel -CloudPC $CloudPC)"
            return
        }

        foreach ($item in $result.value) {
            [PSCustomObject]@{
                CloudPCName         = $targetName
                CloudPCId           = $targetId
                actionName          = $item.actionName
                actionState         = $item.actionState
                startDateTime       = $item.startDateTime
                lastUpdatedDateTime = $item.lastUpdatedDateTime
                managedDeviceId     = $item.managedDeviceId
                statusDetails       = $item.statusDetails
            }
        }
    }
}
