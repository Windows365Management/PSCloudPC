function Invoke-CPCCreateSnapshot {
    <#
        .SYNOPSIS
        Creates an on-demand snapshot for a Cloud PC
        .DESCRIPTION
        The function triggers an on-demand snapshot (restore point) for a specific
        Cloud PC via the Microsoft Graph Windows 365 createSnapshot API (beta).
        This is useful for creating a checkpoint before risky changes such as
        software installs, OS upgrades, or configuration changes.

        Optionally, the snapshot can be exported to an Azure Blob Storage account
        by providing a StorageAccountId. When exporting, you can also specify the
        storage access tier (hot, cool, cold, archive).

        .PARAMETER Name
        Enter the display name or managed device name of the Cloud PC

        .PARAMETER StorageAccountId
        Optional. The resource ID of the Azure Storage Account to which the snapshot
        should be exported. If omitted, the snapshot is kept in the Windows 365 service.

        .PARAMETER AccessTier
        Optional. The blob access tier when exporting to a storage account.
        Valid values: hot, cool, cold, archive. Default: hot.
        Only used when StorageAccountId is provided.

        .EXAMPLE
        Invoke-CPCCreateSnapshot -Name "CloudPC01"

        .EXAMPLE
        Invoke-CPCCreateSnapshot -Name "CloudPC01" -StorageAccountId "/subscriptions/xxx/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/myaccount"

        .EXAMPLE
        Invoke-CPCCreateSnapshot -Name "CloudPC01" -StorageAccountId "/subscriptions/xxx/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/myaccount" -AccessTier "cool"

        .NOTES
        Requires CloudPC.ReadWrite.All permission (delegated or application).
        API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-createsnapshot?view=graph-rest-beta
        Note: This API is currently available in the /beta endpoint only.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [string]
        $StorageAccountId,

        [Parameter(Mandatory = $false)]
        [ValidateSet("hot", "cool", "cold", "archive")]
        [string]
        $AccessTier = "hot"
    )

    begin {
        Get-TokenValidity

        $CloudPC = Get-CloudPC -Name $Name

        if ($null -eq $CloudPC) {
            Write-Error "No Cloud PC found with name '$Name'"
            return
        }
    }

    Process {
        # createSnapshot is a beta-only API; always use beta endpoint
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/createSnapshot"

        Write-Verbose "Creating snapshot for Cloud PC '$($CloudPC.displayName)' (id: $($CloudPC.id))"

        # Build request body — only include storage params when StorageAccountId is provided
        if ($PSBoundParameters.ContainsKey("StorageAccountId")) {
            $body = @{
                storageAccountId = $StorageAccountId
                accessTier       = $AccessTier
            } | ConvertTo-Json -Depth 10
        }
        else {
            $body = $null
        }

        if ($PSCmdlet.ShouldProcess($CloudPC.displayName, "Create on-demand snapshot")) {
            try {
                if ($null -ne $body) {
                    Invoke-RestMethod -Uri $url -Method POST -Headers $script:Authheader -Body $body -ContentType "application/json"
                }
                else {
                    Invoke-RestMethod -Uri $url -Method POST -Headers $script:Authheader
                }
                Write-Verbose "Snapshot request submitted successfully for Cloud PC '$($CloudPC.displayName)'"
                Write-Output "Snapshot creation triggered for Cloud PC '$($CloudPC.displayName)'. Use Get-CPCRestorePoint to check when it is available."
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
