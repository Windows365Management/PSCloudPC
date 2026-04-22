function Get-CPCRemoteActionResult {
    <#
    .SYNOPSIS
    Retrieves the results of remote actions performed on a Cloud PC
    .DESCRIPTION
    The function retrieves the remote action results for a specific Cloud PC using the
    Microsoft Graph beta API. Each result describes a remote action that was triggered
    (such as Reprovision, Reboot, Rename, Resize, Restore, PowerOn, PowerOff, etc.),
    including when it was initiated, the current status, and any error details.

    This is useful for tracking the outcome of remote management actions, diagnosing
    why an action failed, and auditing what actions have been performed on a Cloud PC.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId.
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
    .NOTES
    Requires CloudPC.ReadWrite.All permission (delegated or application).
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
                    CloudPCName        = $targetName
                    CloudPCId          = $targetId
                    actionName         = $_.actionName
                    actionState        = $_.actionState
                    startDateTime      = $_.startDateTime
                    lastUpdatedDateTime = $_.lastUpdatedDateTime
                    cloudPcId          = $_.cloudPcId
                    managedDeviceId    = $_.managedDeviceId
                    statusDetails      = $_.statusDetails
                    statusDetail       = $_.statusDetail
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
