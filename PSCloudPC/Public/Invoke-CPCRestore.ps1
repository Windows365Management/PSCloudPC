function Invoke-CPCRestore {
    <#
    .SYNOPSIS
    Restore a Cloud PC to a certain point in time with
    .DESCRIPTION
    The function will restore a Cloud PC to a certain point in time
    .PARAMETER Name
    Enter the Cloud PC display name
    .EXAMPLE
    Invoke-CPCRestorePoint -Name "CloudPC01"
    #>

    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [string]$Name
    )
    
    begin {
        Get-TokenValidity
        
        $CloudPC = Get-CloudPC -name $Name
        
        $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($CloudPC.managedDeviceId)/restoreCloudPc"
        Write-Verbose "URL: $url"

        $RestorePoints = Get-CPCRestorePoint -name $Name

    }

    Process {
        
        $SelectedRestorePoint = $RestorePoints | Out-GridView -OutputMode Single -Title "Select restore point"

        If($null -eq $SelectedRestorePoint) {
            Write-Error "No restore point selected"
            break
        }

        Write-Verbose "Selected restore point: $($SelectedRestorePoint.id)"

        $params = @{
            CloudPcSnapshotId = $($SelectedRestorePoint.id)
        } | ConvertTo-Json -Depth 10

        try {
            Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params
        }
        catch {
            Throw $_.Exception.Message
        }
    
    }
}