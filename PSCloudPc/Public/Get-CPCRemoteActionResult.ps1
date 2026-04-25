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
    providing the Cloud PC object ID directly via -CloudPCId.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name.
    .EXAMPLE
    Get-CPCRemoteActionResult -Name "CPC-User-XXXX"
    .EXAMPLE
    Get-CPCRemoteActionResult -CloudPCId "4b5ad5e0-6a0b-4ffc-818d-36bb23cf4dbd"
    .EXAMPLE
    Get-CPCRemoteActionResult -Name "CPC-User-XXXX" | Where-Object { $_.actionState -eq 'failed' }
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    This function uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-retrievecloudpcremoteactionresults
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
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
            $targetId   = $CloudPC.id
            $targetName = $CloudPC.displayName
        }
        else {
            $targetId   = $CloudPCId
            $targetName = $CloudPCId
        }

        # retrieveCloudPcRemoteActionResults is a beta-only API
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$targetId/retrieveCloudPcRemoteActionResults"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Retrieving remote action results for Cloud PC '$targetName' (id: $targetId)"

        try {
            $result = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method GET -ContentType "application/json"

            if ($null -eq $result -or $null -eq $result.value -or $result.value.Count -eq 0) {
                Write-Output "No remote action results found for Cloud PC '$targetName'."
                return
            }

            $PSObjectResults = @()
            $result.value | ForEach-Object {
                $entry = [PSCustomObject]@{
                    CloudPCName         = $targetName
                    CloudPCId           = $targetId
                    actionName          = $_.actionName
                    actionState         = $_.actionState
                    startDateTime       = $_.startDateTime
                    lastUpdatedDateTime = $_.lastUpdatedDateTime
                    managedDeviceId     = $_.managedDeviceId
                    statusDetails       = $_.statusDetails
                }
                $PSObjectResults += $entry
            }

            return $PSObjectResults
        }
        catch {
            Throw $_.Exception.Message
        }
    }
}
