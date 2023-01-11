function Get-CPCRestorePoint {
    <#
    .SYNOPSIS
    Get all Cloud PC restore points
    .DESCRIPTION
    The function will restore a Cloud PC to a certain point in time
    .PARAMETER Name
    Enter the Cloud PC display name
    .EXAMPLE
    Get-CPCRestorePoint -Name "CloudPC01"
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ParameterSetName = "Name")]
        [string]$Name
    )
    
    begin {
        Get-TokenValidity
        
        $CloudPC = Get-CloudPC -name $Name
        
        $URL = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/snapshots?`$filter=cloudPcId+eq+'$($CloudPC.Id)'"

    }

    Process {
        write-verbose $url
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
        if ($null -eq $result) {
            Write-Error "No CloudPC restore points returned"
            break
        }

        $resultnew = $result.content | ConvertFrom-Json
        $resultnew.value | ForEach-Object {
    
            $Info = [PSCustomObject]@{
                id                   = $_.id
                CloudPC              = $($CloudPC.displayName)
                status               = $_.status
                createdDateTime      = $_.createdDateTime
                lastRestoredDateTime = $_.lastRestoredDateTime
                
            }
            $Info
    
        }
    
    }
}