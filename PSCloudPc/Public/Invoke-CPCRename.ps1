function Invoke-CPCRename {
    <#
        .SYNOPSIS
        Renames a Cloud PC
        .DESCRIPTION
        The function will rename a Cloud PC by updating its displayName via the
        Microsoft Graph Windows 365 rename API (v1.0).
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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $NewDisplayName
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

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/rename"

        Write-Verbose "Renaming Cloud PC '$($CloudPC.displayName)' (id: $($CloudPC.id)) to '$NewDisplayName'"

        $params = @{
            displayName = $NewDisplayName
        } | ConvertTo-Json -Depth 10

        try {
            Invoke-RestMethod -Uri $url -Method POST -Headers $script:Authheader -Body $params -ContentType "application/json"
            Write-Verbose "Cloud PC '$($CloudPC.displayName)' successfully renamed to '$NewDisplayName'"
        }
        catch {
            Throw $_.Exception.Message
        }

    }
}
