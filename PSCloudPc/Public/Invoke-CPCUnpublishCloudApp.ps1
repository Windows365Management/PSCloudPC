function Invoke-CPCUnpublishCloudApp {
    <#
    .SYNOPSIS
    UnPublishes a Cloud App to make it unavailable to users

    .DESCRIPTION
    The function will unPublishes a Cloud App to make it unavailable to users

    .PARAMETER Id
    Enter the id of the Cloud App

    .PARAMETER Name
    Enter the name of the Cloud App

    .PARAMETER InputObject
    Cloud App object from Get-CloudApp

    .EXAMPLE
    Invoke-CPCUnpublishCloudApp -Id "c1a2b3d4-e5f6-7g8h-9i0j-k1l2m3n4o5p6"

    .EXAMPLE
    Invoke-CPCUnpublishCloudApp -Name "Microsoft Access"

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
        $AllApps = Get-CloudApp
        $PublishedApps = $AllApps | Where-Object { $_.appStatus -eq "published" }

        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudApps/unpublish"
        Write-Verbose "URL: $url"

        # Initialize array to collect app IDs for batch processing
        $AppsToUnpublish = @()

        # Flag to track if we should proceed
        $script:ShouldProceed = $true

        # Check if there are published apps available
        if ($null -eq $PublishedApps -or $PublishedApps.Count -eq 0) {
            Write-Warning "No published apps available to unpublish"
            $script:ShouldProceed = $false
        }
    }

    process {
        # Skip processing if we shouldn't proceed
        if (-not $script:ShouldProceed) {
            return
        }

        $AppId = $null

        switch ($PsCmdlet.ParameterSetName) {
            'Id' {
                Write-Verbose "Processing by Id: $Id"
                # Find the app by ID in published apps
                $App = $PublishedApps | Where-Object { $_.id -eq $Id }
                if ($null -eq $App) {
                    # Check if app exists but is not published
                    $AppExists = $AllApps | Where-Object { $_.id -eq $Id }
                    if ($AppExists) {
                        Write-Warning "App with ID '$Id' exists but is not currently published. App status: $($AppExists.appStatus)"
                    } else {
                        Write-Error "No app found with ID: $Id"
                    }
                    return
                }
                $AppId = $App.id
                Write-Verbose "Found published app: $($App.displayName) (ID: $AppId)"
            }

            'Name' {
                Write-Verbose "Processing by Name: $Name"
                # Find the app by display name in published apps
                $App = $PublishedApps | Where-Object { $_.displayName -like "*$Name*" }
                if ($null -eq $App) {
                    # Check if app exists but is not published
                    $AppExists = $AllApps | Where-Object { $_.displayName -like "*$Name*" }
                    if ($AppExists) {
                        Write-Warning "App matching '$Name' exists but is not currently published. App: '$($AppExists.displayName)' Status: $($AppExists.appStatus)"
                    } else {
                        Write-Error "No app found with name containing: $Name"
                    }
                    return
                }
                if ($App.Count -gt 1) {
                    Write-Warning "Multiple published apps found matching '$Name'. Using first match: $($App[0].displayName)"
                    $App = $App[0]
                }
                $AppId = $App.id
                Write-Verbose "Found published app: $($App.displayName) (ID: $AppId)"
            }

            'InputObject' {
                Write-Verbose "Processing from pipeline object"
                if ($null -eq $InputObject.id) {
                    Write-Error "Input object does not contain an 'id' property"
                    return
                }

                # Check if the piped app is published
                $App = $PublishedApps | Where-Object { $_.id -eq $InputObject.id }
                if ($null -eq $App) {
                    Write-Warning "App '$($InputObject.displayName)' (ID: $($InputObject.id)) is not currently published. Status: $($InputObject.appStatus)"
                    return
                }

                $AppId = $InputObject.id
                Write-Verbose "Processing published app: $($InputObject.displayName) (ID: $AppId)"
            }
        }

        # Add to collection for batch processing
        if ($AppId) {
            $AppsToUnpublish += $AppId
        }
    }

    end {
        # Only proceed if we should and have apps to unpublish
        if (-not $script:ShouldProceed -or $AppsToUnpublish.Count -eq 0) {
            if ($script:ShouldProceed -and $AppsToUnpublish.Count -eq 0) {
                Write-Warning "No apps to unpublish"
            }
            return
        }

        Write-Verbose "Unpublishing $($AppsToUnpublish.Count) app(s)"

        # Prepare the request body
        $params = @{
            cloudAppIds = $AppsToUnpublish
        } | ConvertTo-Json -Depth 10

        Write-Verbose "Request body: $params"

        try {
            $result = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params

            # Output success message for each unpublished app
            foreach ($AppId in $AppsToUnpublish) {
                $App = $PublishedApps | Where-Object { $_.id -eq $AppId }
                if ($App) {
                    Write-Output "Successfully unpublished app: $($App.displayName) (ID: $AppId)"
                } else {
                    Write-Output "Successfully unpublished app with ID: $AppId"
                }
            }
        }
        catch {
            Write-Error "Failed to unpublish app(s): $($_.Exception.Message)"
            throw
        }
    }
}