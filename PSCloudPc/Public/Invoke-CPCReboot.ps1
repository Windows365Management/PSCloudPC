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
        .NOTES
        Required permission: CloudPC.ReadWrite.All
        https://learn.microsoft.com/graph/api/cloudpc-reboot?view=graph-rest-beta
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )
    begin {

        Get-TokenValidity

        $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -Name $Name

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/reboot"
        
    }
    Process {

        Write-Verbose "Rebooting CloudPC $($CloudPC.displayName) with id: $($CloudPC.id)"

        if ($PSCmdlet.ShouldProcess($CloudPC.displayName, "Reboot Cloud PC")) {
            try {
                # Graph returns 204 No Content
                $null = Invoke-RestMethod -Uri $url -Method POST -Headers $script:Authheader
                Write-Output "Reboot initiated for Cloud PC '$($CloudPC.displayName)'"
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }
}
