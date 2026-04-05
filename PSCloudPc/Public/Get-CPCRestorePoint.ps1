function Get-CPCRestorePoint {
    <#
    .SYNOPSIS
    Get all restore point snapshots for a Cloud PC.
    .DESCRIPTION
    Returns all available restore point snapshots for a given Cloud PC.
    Snapshots can be used with Invoke-CPCRestore to restore the Cloud PC to
    a previous state.
    .PARAMETER Name
    The display name of the Cloud PC.
    .EXAMPLE
    Get-CPCRestorePoint -Name "CloudPC01"
    .EXAMPLE
    $snapshots = Get-CPCRestorePoint -Name "CloudPC01"
    $snapshots | Select-Object id, status, createdDateTime
    .NOTES
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-retrievesnapshots
    Required permission: CloudPC.Read.All
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    begin {
        Get-TokenValidity

        $CloudPC = Get-CloudPC -name $Name

        if ($null -eq $CloudPC) {
            Throw "No Cloud PC found with name '$Name'"
            return
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/snapshots"

        Write-Verbose "URL: $url"
    }

    Process {
        try {
            $result = Invoke-RestMethod -Uri $url -Method GET -Headers $script:Authheader

            if ($null -eq $result -or $null -eq $result.value) {
                Write-Error "No restore points returned for Cloud PC '$Name'"
                return
            }

            $returnResults = @()
            $result.value | ForEach-Object {
                $Info = [PSCustomObject]@{
                    id                   = $_.id
                    CloudPC              = $CloudPC.displayName
                    status               = $_.status
                    createdDateTime      = $_.createdDateTime
                    lastRestoredDateTime = $_.lastRestoredDateTime
                    expirationDateTime   = $_.expirationDateTime
                    snapshotType         = $_.snapshotType
                }
                $returnResults += $Info
            }
            return $returnResults
        }
        catch {
            Throw $_.Exception.Message
        }
    }
}
