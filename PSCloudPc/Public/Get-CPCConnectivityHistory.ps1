function Get-CPCConnectivityHistory {
    <#
    .SYNOPSIS
    Retrieves the connectivity history for a specific Cloud PC
    .DESCRIPTION
    The function retrieves the connectivity event history for a specific Cloud PC
    using the Microsoft Graph beta API. Each event describes a user connection attempt,
    including when it occurred, the event type, and whether the connection succeeded or failed.

    This is useful for diagnosing connectivity issues, identifying failed sessions,
    and understanding usage patterns for a Cloud PC.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name.
    .EXAMPLE
    Get-CPCConnectivityHistory -Name "CPC-User-XXXX"
    .EXAMPLE
    Get-CPCConnectivityHistory -CloudPCId "4b5ad5e0-6a0b-4ffc-818d-36bb23cf4dbd"
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    This function uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-getcloudpcconnectivityhistory
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

        # getCloudPcConnectivityHistory is a beta-only API
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$targetId/getCloudPcConnectivityHistory"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Retrieving connectivity history for Cloud PC '$targetName' (id: $targetId)"

        try {
            $result = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method GET -ContentType "application/json"

            if ($null -eq $result -or $null -eq $result.value -or $result.value.Count -eq 0) {
                Write-Output "No connectivity history found for Cloud PC '$targetName'."
                return
            }

            $PSObjectResults = @()
            $result.value | ForEach-Object {
                $event = [PSCustomObject]@{
                    CloudPCName   = $targetName
                    CloudPCId     = $targetId
                    eventDateTime = $_.eventDateTime
                    eventName     = $_.eventName
                    eventType     = $_.eventType
                    eventResult   = $_.eventResult
                    activityId    = $_.activityId
                    message       = $_.message
                }
                $PSObjectResults += $event
            }

            return $PSObjectResults
        }
        catch {
            Throw $_.Exception.Message
        }
    }
}
