function Invoke-CPCReprovision {
    <#
    .SYNOPSIS
    Restore a Cloud PC to a certain point in time with
    .DESCRIPTION
    The function will restore a Cloud PC to a certain point in time
    .PARAMETER Name
    Enter the Cloud PC display name
    .EXAMPLE
    Invoke-CPCReprovision -Name "CloudPC01"
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [string]$Name
    )
    
    begin {
        Get-TokenValidity
        
        $CloudPC = Get-CloudPC -name $Name
        
        $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($CloudPC.managedDeviceId)/reprovisionCloudPc"

        Write-Verbose "URL: $url"
        }

    Process {

        try {
            Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST
            Write-Output "Cloud PC $($CloudPC.displayName) reprovisioned"
        }
        catch {
            Throw $_.Exception.Message
        }
    
    }
}