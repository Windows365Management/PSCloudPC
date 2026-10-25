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
    .PARAMETER Name
    The display name of the Cloud PC to restore.
    .PARAMETER SnapshotId
    The unique identifier of the restore-point snapshot to restore to. Use
    Get-CPCRestorePoint to obtain snapshot IDs. When this parameter is supplied
    the function runs non-interactively without opening a GUI selector.
    .EXAMPLE
    Invoke-CPCRestore -Name "CloudPC01"
    # Interactive: opens a restore-point picker GUI.
    .EXAMPLE
    Invoke-CPCRestore -Name "CloudPC01" -SnapshotId "CPC_d4cfdeb2-d409-4e97-87ce-618b704d75f1_d95c0bde-485d-400e-9bef-083905e1b768"
    # Non-interactive: restores to the given snapshot.
    .NOTES
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-restore
    Required permission: CloudPC.ReadWrite.All
    #>

    [CmdletBinding(DefaultParameterSetName = 'Interactive', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$SnapshotId
    )

    begin {
        Get-TokenValidity

        $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -Name $Name

        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/restore"
        Write-Verbose "Restore URL: $url"

        If (-not $PSBoundParameters.ContainsKey('SnapshotId')) {
            If (-not (Get-Command -Name Out-GridView -ErrorAction SilentlyContinue)) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Out-GridView is not available in this session. Pass -SnapshotId (see Get-CPCRestorePoint) to restore without the interactive selector." -Category NotImplemented
            }
            $RestorePoints = @(Get-CPCRestorePoint -name $Name)
            If ($RestorePoints.Count -eq 0) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No restore points found for Cloud PC '$Name'" -Category ObjectNotFound
            }
        }
    }

    Process {

        If ($PSBoundParameters.ContainsKey('SnapshotId')) {
            $selectedSnapshotId = $SnapshotId
            Write-Verbose "Using provided SnapshotId: $selectedSnapshotId"
        }
        Else {
            $SelectedRestorePoint = $RestorePoints | Out-GridView -OutputMode Single -Title "Select restore point for '$Name'"

            If ($null -eq $SelectedRestorePoint) {
                Write-Error "No restore point selected"
                return
            }

            $selectedSnapshotId = $SelectedRestorePoint.id
            Write-Verbose "Selected restore point: $selectedSnapshotId"
        }

        $params = @{
            cloudPcSnapshotId = $selectedSnapshotId
        } | ConvertTo-Json -Depth 10

        If ($PSCmdlet.ShouldProcess($Name, "Restore Cloud PC to snapshot '$selectedSnapshotId'")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params
                Write-Verbose "Restore initiated for Cloud PC '$Name'"
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }
}
