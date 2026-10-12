function Invoke-CPCRestore {
    <#
    .SYNOPSIS
    Restore a Cloud PC to a certain point in time.
    .DESCRIPTION
    Restore a Cloud PC to a previous state using a snapshot. When -SnapshotId is
    provided the restore runs non-interactively and is safe to call from automation
    scripts or pipelines. When -SnapshotId is omitted the user is presented with
    an interactive Out-GridView selector to choose a restore point (requires a
    graphical session).

    Identify the Cloud PC by its managed device name (-Name) or by its id (-CloudPCId).
    -CloudPCId also takes Cloud PC objects from the pipeline, such as the output of
    Get-CloudPC. A snapshot id belongs to one Cloud PC, so when you pipe several Cloud PCs,
    leave out -SnapshotId and pick a restore point per Cloud PC.

    Restoring overwrites the current state of the Cloud PC, so the command asks for
    confirmation for each Cloud PC. Use -Confirm:$false to skip the prompt in automation.
    The name must match the managed device name of exactly one Cloud PC; otherwise no
    request is sent. The command returns no output when the request is accepted.

    A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
    non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
    with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
    -ErrorVariable and $Error can also hold the underlying Graph errors.
    .PARAMETER Name
    The managed device name of the Cloud PC to restore. Use Get-CloudPC to find Cloud PC names.
    .PARAMETER SnapshotId
    The unique identifier of the restore-point snapshot to restore to. Use
    Get-CPCRestorePoint to obtain snapshot IDs. When this parameter is supplied
    the function runs non-interactively without opening a GUI selector.
    .PARAMETER CloudPCId
    The id of the Cloud PC. Accepts pipeline input by property name (id or CloudPCId), for example from Get-CloudPC.
    .EXAMPLE
    Invoke-CPCRestore -Name "CPC-User-XXXX"
    # Interactive: opens a restore-point picker GUI.
    .EXAMPLE
    Invoke-CPCRestore -Name "CPC-User-XXXX" -SnapshotId "00000000-0000-0000-0000-000000000000" -Confirm:$false
    # Restores a restore point without the picker; get the id from Get-CPCRestorePoint.
    .EXAMPLE
    Invoke-CPCRestore -CloudPCId "00000000-0000-0000-0000-000000000000"
    # Pipeline: Get-CloudPC -Name "CPC-User-XXXX" | Invoke-CPCRestore
    .NOTES
    Required permission: CloudPC.ReadWrite.All (delegated or application).
    POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/restore with body { "cloudPcSnapshotId": "<snapshot id>" }
    https://learn.microsoft.com/graph/api/cloudpc-restore?view=graph-rest-beta
    #>

    [CmdletBinding(DefaultParameterSetName = 'Interactive', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$SnapshotId,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    begin {
        Get-TokenValidity
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'Id') {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -CloudPCId $CloudPCId
        }
        else {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -Name $Name
        }

        # The lookup wrote an error for this Cloud PC; continue with the next pipeline object
        if ($null -eq $CloudPC) {
            return
        }

        $targetName = Get-CPCCloudPCLabel -CloudPC $CloudPC
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/restore"

        If ($PSBoundParameters.ContainsKey('SnapshotId')) {
            $selectedSnapshotId = $SnapshotId
            Write-Verbose "Using provided SnapshotId: $selectedSnapshotId"
        }
        Else {
            $RestorePoints = Get-CPCRestorePoint -CloudPCId $CloudPC.id
            $SelectedRestorePoint = $RestorePoints | Out-GridView -OutputMode Single -Title "Select restore point for $targetName"

            If ($null -eq $SelectedRestorePoint) {
                Write-Error "No restore point selected for Cloud PC $targetName"
                return
            }

            $selectedSnapshotId = $SelectedRestorePoint.id
            Write-Verbose "Selected restore point: $selectedSnapshotId"
        }

        $params = @{
            cloudPcSnapshotId = $selectedSnapshotId
        } | ConvertTo-Json -Depth 10

        If ($PSCmdlet.ShouldProcess($targetName, "Restore Cloud PC to snapshot '$selectedSnapshotId'")) {
            Write-Verbose "Request: POST $url"
            try {
                $null = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params -ErrorAction Stop
                Write-Verbose "Restore requested for Cloud PC $targetName"
            }
            catch {
                Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Restore" -CloudPC $CloudPC
                return
            }
        }
    }
}
