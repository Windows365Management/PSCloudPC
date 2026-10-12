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

        Identify the Cloud PC by its managed device name (-Name) or by its id (-CloudPCId).
        -CloudPCId also takes Cloud PC objects from the pipeline, such as the output of
        Get-CloudPC; the storage options apply to every piped Cloud PC.
        The name must match the managed device name of exactly one Cloud PC; otherwise
        no request is sent. The command returns no output when the request is accepted.
        Use Get-CPCRestorePoint to check when the snapshot is available.

        A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
        non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
        with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
        -ErrorVariable and $Error can also hold the underlying Graph errors.

        .PARAMETER Name
        Enter the managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.

        .PARAMETER StorageAccountId
        Optional. The resource ID of the Azure Storage Account to which the snapshot
        should be exported. If omitted, the snapshot is kept in the Windows 365 service.

        .PARAMETER AccessTier
        Optional. The blob access tier when exporting to a storage account.
        Valid values: hot, cool, cold, archive. Default: hot.
        Only used when StorageAccountId is provided.

        .PARAMETER CloudPCId
        The id of the Cloud PC. Accepts pipeline input by property name (id or CloudPCId), for example from Get-CloudPC.

        .EXAMPLE
        Invoke-CPCCreateSnapshot -Name "CPC-User-XXXX"

        .EXAMPLE
        Invoke-CPCCreateSnapshot -Name "CPC-User-XXXX" -StorageAccountId "/subscriptions/xxx/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/myaccount"

        .EXAMPLE
        Invoke-CPCCreateSnapshot -Name "CPC-User-XXXX" -StorageAccountId "/subscriptions/xxx/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/myaccount" -AccessTier "cool"

        .EXAMPLE
        Invoke-CPCCreateSnapshot -CloudPCId "00000000-0000-0000-0000-000000000000"
        # Pipeline: Get-CloudPC | Where-Object { $_.provisioningPolicyName -eq "Developers" } | Invoke-CPCCreateSnapshot

        .NOTES
        Required permission: CloudPC.ReadWrite.All (delegated or application).
        POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/createSnapshot, with no body or
        with body { "storageAccountId": "...", "accessTier": "..." } when -StorageAccountId is used.
        https://learn.microsoft.com/graph/api/cloudpc-createsnapshot?view=graph-rest-beta
        Note: This API is currently available in the /beta endpoint only.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $StorageAccountId,

        [Parameter(Mandatory = $false)]
        [ValidateSet("hot", "cool", "cold", "archive")]
        [string]
        $AccessTier = "hot",

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]
        $CloudPCId
    )

    begin {
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
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/createSnapshot"

        # Build request body — only include storage params when StorageAccountId is provided
        if ($PSBoundParameters.ContainsKey("StorageAccountId")) {
            $body = @{
                storageAccountId = $StorageAccountId
                # ValidateSet ignores case; the documented values are lowercase
                accessTier       = $AccessTier.ToLowerInvariant()
            } | ConvertTo-Json -Depth 10
        }
        else {
            $body = $null
        }

        if ($PSCmdlet.ShouldProcess($targetName, "Create on-demand snapshot")) {
            Write-Verbose "Request: POST $url"
            try {
                if ($null -ne $body) {
                    $null = Invoke-RestMethod -Uri $url -Method POST -Headers $script:Authheader -Body $body -ContentType "application/json" -ErrorAction Stop
                }
                else {
                    $null = Invoke-RestMethod -Uri $url -Method POST -Headers $script:Authheader -ErrorAction Stop
                }
                Write-Verbose "Snapshot requested for Cloud PC $targetName. Use Get-CPCRestorePoint to check when it is available."
            }
            catch {
                Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Create snapshot" -CloudPC $CloudPC
                return
            }
        }
    }
}
