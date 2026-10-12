function Get-CPCRestorePoint {
    <#
    .SYNOPSIS
    Get all restore point snapshots for a Cloud PC.
    .DESCRIPTION
    Returns all available restore point snapshots for a given Cloud PC.
    Snapshots can be used with Invoke-CPCRestore to restore the Cloud PC to
    a previous state.

    Identify the Cloud PC by its managed device name (-Name) or by its id (-CloudPCId).
    -CloudPCId also takes Cloud PC objects from the pipeline, such as the output of
    Get-CloudPC. The name must match exactly one Cloud PC. When a Cloud PC has no
    restore points, nothing is returned for it.

    Returns one object per restore point with id, CloudPC, status, createdDateTime,
    lastRestoredDateTime, expirationDateTime and snapshotType.
    CloudPC is the managed device name (the Intune device name) that -Name expects. It is
    empty while the Cloud PC is still provisioning and for Windows 365 Business Cloud PCs;
    use the Cloud PC id with -CloudPCId for those.

    A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
    non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
    with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
    -ErrorVariable and $Error can also hold the underlying Graph errors.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    .PARAMETER CloudPCId
    The id of the Cloud PC. Accepts pipeline input by property name (id or CloudPCId), for example from Get-CloudPC.
    .EXAMPLE
    Get-CPCRestorePoint -Name "CPC-User-XXXX"
    .EXAMPLE
    Get-CPCRestorePoint -CloudPCId "00000000-0000-0000-0000-000000000000"
    # Pipeline: Get-CloudPC | Get-CPCRestorePoint | Sort-Object createdDateTime -Descending
    .NOTES
    Required permission: CloudPC.Read.All
    GET /deviceManagement/virtualEndpoint/cloudPCs/{id}/retrieveSnapshots
    https://learn.microsoft.com/graph/api/cloudpc-retrievesnapshots?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
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

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/retrieveSnapshots"
        Write-Verbose "Request: GET $url"

        try {
            $result = Invoke-RestMethod -Uri $url -Method GET -Headers $script:Authheader -ErrorAction Stop
        }
        catch {
            Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Get restore points" -CloudPC $CloudPC
            return
        }

        if ($null -eq $result -or $null -eq $result.value -or @($result.value).Count -eq 0) {
            Write-Verbose "No restore points returned for Cloud PC $(Get-CPCCloudPCLabel -CloudPC $CloudPC)"
            return
        }

        foreach ($item in $result.value) {
            [PSCustomObject]@{
                id                   = $item.id
                CloudPC              = (Get-CPCCloudPCName -CloudPC $CloudPC)
                status               = $item.status
                createdDateTime      = $item.createdDateTime
                lastRestoredDateTime = $item.lastRestoredDateTime
                expirationDateTime   = $item.expirationDateTime
                snapshotType         = $item.snapshotType
            }
        }
    }
}
