function Get-CPCSupportedRemoteAction {
    <#
    .SYNOPSIS
    Retrieves the list of supported remote actions for a specific Cloud PC
    .DESCRIPTION
    The function retrieves the supported Cloud PC remote actions for a specific Cloud PC
    device using the Microsoft Graph beta API. Each entry describes an action name and
    its capability (for example, whether the action is supported and any requirements).

    This is useful before attempting remote actions such as restart, reprovision,
    resize, restore, or troubleshoot — you can confirm in advance which actions are
    available for that particular Cloud PC (based on its license type, provisioning
    policy, and current state) rather than receiving an error at execution time.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name.
    .EXAMPLE
    Get-CPCSupportedRemoteAction -Name "CPC-User-XXXX"

    Returns all supported remote actions for the Cloud PC with managed device name "CPC-User-XXXX".
    .EXAMPLE
    Get-CPCSupportedRemoteAction -CloudPCId "4b5ad5e0-6a0b-4ffc-818d-36bb23cf4dbd"

    Returns all supported remote actions for the Cloud PC identified by the given object ID.
    .EXAMPLE
    Get-CPCSupportedRemoteAction -Name "CPC-User-XXXX" | Where-Object { $_.actionState -eq "enabled" }

    Filters to only the enabled (currently usable) remote actions.
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    This function uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-getsupportedcloudpcremoteactions
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
            $targetId = $CloudPC.id
            $targetName = $CloudPC.displayName
        }
        else {
            $targetId = $CloudPCId
            $targetName = $CloudPCId
        }

        # getSupportedCloudPcRemoteActions is a beta-only API
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$targetId/getSupportedCloudPcRemoteActions"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Retrieving supported remote actions for Cloud PC '$targetName' (id: $targetId)"

        try {
            $result = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method GET -ContentType "application/json"

            if ($null -eq $result -or $null -eq $result.value -or $result.value.Count -eq 0) {
                Write-Output "No supported remote actions found for Cloud PC '$targetName'."
                return
            }

            $PSObjectResults = @()
            $result.value | ForEach-Object {
                $action = [PSCustomObject]@{
                    CloudPCName              = $targetName
                    CloudPCId                = $targetId
                    actionName               = $_.actionName
                    actionState              = $_.actionState
                    actionableMessage        = $_.actionableMessage
                    clientOperationId        = $_.clientOperationId
                }
                $PSObjectResults += $action
            }

            return $PSObjectResults
        }
        catch {
            Throw $_.Exception.Message
        }
    }
}
