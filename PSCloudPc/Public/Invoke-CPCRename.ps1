function Invoke-CPCRename {
    <#
        .SYNOPSIS
        Renames a Cloud PC
        .DESCRIPTION
        The function will rename a Cloud PC by updating its displayName via the
        Microsoft Graph Windows 365 rename API.
        .PARAMETER Name
        Enter the current name (managedDeviceName or displayName) of the Cloud PC to rename
        .PARAMETER NewDisplayName
        Enter the new display name to assign to the Cloud PC
        .EXAMPLE
        Invoke-CPCRename -Name "CloudPC01" -NewDisplayName "Marketing-CloudPC-01"
        .NOTES
        Requires CloudPC.ReadWrite.All permission (delegated or application).
        API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-rename
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NewDisplayName
    )
    begin {

        Get-TokenValidity

        $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -Name $Name

    }
    Process {

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/rename"

        Write-Verbose "Renaming Cloud PC '$($CloudPC.displayName)' (id: $($CloudPC.id)) to '$NewDisplayName'"

        $params = @{
            displayName = $NewDisplayName
        } | ConvertTo-Json -Depth 10

        if ($PSCmdlet.ShouldProcess($CloudPC.displayName, "Rename Cloud PC to '$NewDisplayName'")) {
            try {
                $null = Invoke-RestMethod -Uri $url -Method POST -Headers $script:Authheader -Body $params -ContentType "application/json"
                Write-Verbose "Cloud PC '$($CloudPC.displayName)' successfully renamed to '$NewDisplayName'"
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }

    }
}
