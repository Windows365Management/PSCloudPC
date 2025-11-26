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
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudApps?`$filter=displayName+eq+'$($Name)'"
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
            $result = Invoke-RestMethod -Uri $url -Method GET -Headers $script:authHeader
            
            if ($null -eq $result) {
                Write-Warning "No Cloud Apps returned"
                return
            }

            $returnResults = @()
            
            # Handle single item response (when getting by ID)
            if ($PsCmdlet.ParameterSetName -eq 'Id') {
                $apps = @($result)
            }
            else {
                $apps = $result.value
            }
            
            if ($null -eq $apps -or $apps.Count -eq 0) {
                Write-Warning "No Cloud Apps found"
                return
            }

            $apps | ForEach-Object {
                $Info = [PSCustomObject]@{
                    id                    = $_.id
                    discoveredAppName     = $_.discoveredAppName
                    displayName           = $_.displayName
                    appStatus             = $_.appStatus
                    availableToUser       = $_.availableToUser
                    lastPublishedDateTime = $_.lastPublishedDateTime
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