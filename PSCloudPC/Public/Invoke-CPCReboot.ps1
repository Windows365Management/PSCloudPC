function Invoke-CPCReboot {
    <#
        .SYNOPSIS
        Reboots a CloudPC
        .DESCRIPTION
        The function will reboot a CloudPC
        .PARAMETER Name
        Enter the name of the CloudPC
        .EXAMPLE
        Invoke-CPCReboot -Name "CloudPC01"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    begin {

        Get-TokenValidity

        $CloudPC = Get-CloudPC -Name $Name
        
    }
    Process {

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPc.id)/reboot"

        Write-Verbose "Rebooting CloudPC $($CloudPC.displayName) with id: $($CloudPC.id)"

        $response = Invoke-RestMethod -Uri $url -Method POST -Headers $script:Authheader
    }
}