function Publish-CloudApp{
    <#
    .SYNOPSIS
    Publishes a Cloud App to make it available to users

    .DESCRIPTION
    The function will publish a Cloud App to make it available to users

    .PARAMETER Id
    Enter the id of the Cloud App

    .PARAMETER Name
    Enter the name of the Cloud App
    
    .PARAMETER InputObject
    Cloud App object from Get-CloudApp

    .EXAMPLE
    Publish-CloudApp -Id "c1a2b3d4-e5f6-7g8h-9i0j-k1l2m3n4o5p6"

    .EXAMPLE
    Publish-CloudApp -Name "Microsoft Access"
    
    .EXAMPLE
    Get-CloudApp -Name "Access" | Publish-CloudApp

    .EXAMPLE
    Get-CloudApp | Where-Object { $_.appStatus -eq "available" } | Publish-CloudApp
    #>
    [CmdletBinding(DefaultParameterSetName = 'Id')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [string]$Id,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,
        
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'InputObject')]
        [PSCustomObject]$InputObject
    )

    begin {
        Get-TokenValidity
        
        Write-Verbose "Getting Cloud Apps"
        $AvailableApps = Get-CloudApp
        
        # Check if there are apps available
        if ($null -eq $AvailableApps) {
            Write-Error "No apps available to publish"
            return
        }
        
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudApps/publish"
        Write-Verbose "URL: $url"
        
        # Initialize array to collect app IDs for batch processing
        $AppsToPublish = @()
    }

    process {
        $AppId = $null
        
        switch ($PsCmdlet.ParameterSetName) {
            'Id' {
                Write-Verbose "Processing by Id: $Id"
                # Find the app by ID
                $App = $AvailableApps | Where-Object { $_.id -eq $Id }
                if ($null -eq $App) {
                    Write-Error "No app found with ID: $Id"
                    return
                }
                $AppId = $App.id
                Write-Verbose "Found app: $($App.displayName) (ID: $AppId)"
            }
            
            'Name' {
                Write-Verbose "Processing by Name: $Name"
                # Find the app by display name (case-insensitive)
                $App = $AvailableApps | Where-Object { $_.displayName -like "*$Name*" }
                if ($null -eq $App) {
                    Write-Error "No app found with name containing: $Name"
                    return
                }
                if ($App.Count -gt 1) {
                    Write-Warning "Multiple apps found matching '$Name'. Using first match: $($App[0].displayName)"
                    $App = $App[0]
                }
                $AppId = $App.id
                Write-Verbose "Found app: $($App.displayName) (ID: $AppId)"
            }
            
            'InputObject' {
                Write-Verbose "Processing from pipeline object"
                if ($null -eq $InputObject.id) {
                    Write-Error "Input object does not contain an 'id' property"
                    return
                }
                $AppId = $InputObject.id
                Write-Verbose "Processing app: $($InputObject.displayName) (ID: $AppId)"
            }
        }
        
        # Add to collection for batch processing
        if ($AppId) {
            $AppsToPublish += $AppId
        }
    }

    end {
        if ($AppsToPublish.Count -eq 0) {
            Write-Warning "No apps to publish"
            return
        }
        
        Write-Verbose "Publishing $($AppsToPublish.Count) app(s)"
        
        # Prepare the request body
        $params = @{
            cloudAppIds = $AppsToPublish
        } | ConvertTo-Json -Depth 10
        
        Write-Verbose "Request body: $params"

        try {
            $result = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params
            
            # Output success message for each published app
            foreach ($AppId in $AppsToPublish) {
                $App = $AvailableApps | Where-Object { $_.id -eq $AppId }
                if ($App) {
                    Write-Output "Successfully published app: $($App.displayName) (ID: $AppId)"
                } else {
                    Write-Output "Successfully published app with ID: $AppId"
                }
            }
        }
        catch {
            Write-Error "Failed to publish app(s): $($_.Exception.Message)"
            throw
        }
    }
}