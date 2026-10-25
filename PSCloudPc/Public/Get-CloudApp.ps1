function Get-CloudApp {
    <#
    .SYNOPSIS
    Returns all Cloud PC Apps or Cloud PC Apps with a specific name
    .DESCRIPTION
    The function will return all Cloud PC Apps or Cloud PC Apps with a specific name
    .PARAMETER Name
    Enter the name of the Cloud PC App
    .PARAMETER Id
    Enter the id of the Cloud PC App
    .EXAMPLE
    Get-CloudApp -Name "Access"
    .EXAMPLE
    Get-CloudApp -Id "c1a2b3d4-e5f6-7g8h-9i0j-k1l2m3n4o5p6"
    .EXAMPLE
    Get-CloudApp
    .EXAMPLE
    Get-CloudApp | Where-Object { $_.appStatus -eq "published" }
    .NOTES
    Required permission: CloudPC.Read.All
    https://learn.microsoft.com/graph/api/virtualendpoint-list-cloudapps?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpccloudapp?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [string]$Id
    )
    
    begin {
        Get-TokenValidity

        switch ($PsCmdlet.ParameterSetName) {
            'Name' {
                Write-Verbose "Name parameter provided: $Name"
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudApps?`$filter=displayName+eq+'$(ConvertTo-CPCODataString $Name)'"
            }
            'Id' {
                Write-Verbose "Id parameter provided: $Id"
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudApps/$Id"
            }
            default {
                Write-Verbose "Getting all Cloud Apps"
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudApps"
            }
        }
        
        Write-Verbose "URL: $url"
    }
    
    process {
        try {
            # Invoke-APIRequest returns a single app as-is and follows every page of a collection
            $apps = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET)

            if ($apps.Count -eq 0) {
                Write-Warning "No Cloud Apps found"
                return
            }

            $returnResults = @()

            $apps | ForEach-Object {
                $Info = [PSCustomObject]@{
                    id                    = $_.id
                    discoveredAppName     = $_.discoveredAppName
                    displayName           = $_.displayName
                    description           = $_.description
                    appStatus             = $_.appStatus
                    availableToUser       = $_.availableToUser
                    provisioningPolicyId  = $_.provisioningPolicyId
                    addedDateTime         = $_.addedDateTime
                    lastPublishedDateTime = $_.lastPublishedDateTime
                    actionFailedErrorCode = $_.actionFailedErrorCode
                }
                $returnResults += $Info
            }
            
            return $returnResults
        }
        catch {
            Write-Error "Failed to retrieve Cloud Apps: $($_.Exception.Message)"
            throw
        }
    }
}
