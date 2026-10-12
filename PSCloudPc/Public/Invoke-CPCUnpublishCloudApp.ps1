function Invoke-CPCUnpublishCloudApp {
    <#
    .SYNOPSIS
    UnPublishes a Cloud App to make it unavailable to users

    .DESCRIPTION
    The function will unpublish a Cloud App to remove it from the end-user portal, for example
    the Windows App. When a Cloud App is unpublished, any changes made to its app details are
    reverted to the values of the discovered app it's linked to.

    -Name must match the display name of exactly one Cloud App (exact, case-insensitive match).
    A display name is only unique within one provisioning policy, so the same name can exist in
    several policies. When the name matches zero or more than one Cloud App, the command stops
    without unpublishing anything and lists the ids and provisioning policy ids of the matches.
    Use -Id to select one of them.

    Only apps with status published or failed are unpublished; other apps are skipped with a
    warning. Unpublishing and then publishing again is the documented fix for a failed app.

    Unpublishing is asynchronous: Graph accepts the request (202 Accepted) and the app status
    changes to unpublishing and then ready. The command outputs one "Unpublish requested" line
    per app; use Get-CloudApp to check the status.

    .PARAMETER Id
    Enter the id of the Cloud App

    .PARAMETER Name
    Enter the exact display name of the Cloud App. The name must match exactly one Cloud App.

    .PARAMETER InputObject
    Cloud App object from Get-CloudApp

    .EXAMPLE
    Invoke-CPCUnpublishCloudApp -Id "00000000-0000-0000-0000-000000000000"

    .EXAMPLE
    Invoke-CPCUnpublishCloudApp -Name "Microsoft Access"

    .EXAMPLE
    Invoke-CPCUnpublishCloudApp -Name "Microsoft Access" -WhatIf

    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/cloudpccloudapp-unpublish?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/virtualendpoint-list-cloudapps?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpccloudapp?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Id', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'InputObject')]
        [PSCustomObject]$InputObject
    )

    begin {
        Get-TokenValidity

        $baseUrl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudApps"
        $url = "$baseUrl/unpublish"
        Write-Verbose "URL: $url"

        # Collect the apps to unpublish; the unpublish action takes a list of ids
        $AppsToUnpublish = [System.Collections.Generic.List[object]]::new()
    }

    process {
        $App = $null

        switch ($PsCmdlet.ParameterSetName) {
            'Id' {
                Write-Verbose "Processing by Id: $Id"
                try {
                    $App = Invoke-APIRequest -uri "$baseUrl/$([uri]::EscapeDataString($Id))" -Token $script:Authtoken -Method GET
                }
                catch {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Cloud App with id '$Id' could not be retrieved: $(Get-GraphErrorMessage $_)" -Category InvalidOperation
                }

                if ($null -eq $App -or [string]::IsNullOrWhiteSpace($App.id)) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Cloud App found with id '$Id'" -Category ObjectNotFound
                }
            }

            'Name' {
                Write-Verbose "Processing by Name: $Name"
                $filterName = [uri]::EscapeDataString($Name.Replace("'", "''"))
                try {
                    $Result = Invoke-APIRequest -uri "$($baseUrl)?`$filter=displayName+eq+'$filterName'" -Token $script:Authtoken -Method GET
                }
                catch {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message (Get-GraphErrorMessage $_) -Category InvalidOperation
                }

                # Exact, case-insensitive match; display names are only unique within one provisioning policy
                $FoundApps = @($Result | Where-Object { $_.displayName -eq $Name })

                if ($FoundApps.Count -eq 0) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Cloud App found with name '$Name'" -Category ObjectNotFound
                }

                if ($FoundApps.Count -gt 1) {
                    $MatchList = ($FoundApps | ForEach-Object { "$($_.id) (provisioning policy $($_.provisioningPolicyId), status $($_.appStatus))" }) -join ", "
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($FoundApps.Count) Cloud Apps found with name '$Name': $MatchList. Use -Id to select one"
                }

                $App = $FoundApps[0]
            }

            'InputObject' {
                Write-Verbose "Processing from pipeline object"
                if ($null -eq $InputObject.id -or $InputObject.id -is [array] -or [string]::IsNullOrWhiteSpace([string]$InputObject.id)) {
                    Write-Error "Input object does not contain a single 'id' value"
                    return
                }

                # Read the current status; the piped object can be out of date
                try {
                    $App = Invoke-APIRequest -uri "$baseUrl/$([uri]::EscapeDataString([string]$InputObject.id))" -Token $script:Authtoken -Method GET
                }
                catch {
                    Write-Error "Cloud App with id '$($InputObject.id)' could not be retrieved: $(Get-GraphErrorMessage $_)"
                    return
                }
            }
        }

        # Unpublish published apps, and failed apps (unpublish + republish is the documented fix for a failed app)
        # https://learn.microsoft.com/windows-365/enterprise/cloud-apps#publish-and-edit-cloud-apps
        if ($App.appStatus -notin @("published", "failed")) {
            Write-Warning "App '$($App.displayName)' (ID: $($App.id)) is not published or failed, so it is not unpublished. App status: $($App.appStatus)"
            return
        }

        Write-Verbose "Found published app: $($App.displayName) (ID: $($App.id))"

        if ($PSCmdlet.ShouldProcess("$($App.displayName) ($($App.id))", "Unpublish Cloud App and reset its app details to the discovered app")) {
            $AppsToUnpublish.Add($App)
        }
    }

    end {
        if ($AppsToUnpublish.Count -eq 0) {
            Write-Verbose "No apps to unpublish"
            return
        }

        Write-Verbose "Unpublishing $($AppsToUnpublish.Count) app(s)"
        Write-Warning "Unpublishing resets the app details (such as display name and icon) of $($AppsToUnpublish.Count) app(s) to the values of the discovered app"

        $body = @{
            cloudAppIds = @($AppsToUnpublish | ForEach-Object { [string]$_.id } | Select-Object -Unique)
        } | ConvertTo-Json -Depth 10

        Write-Verbose "Request: POST $url"
        Write-Verbose "Request body: $body"

        try {
            Invoke-RestMethod -Uri $url -Method POST -Headers $script:Authheader -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
        }
        catch {
            Throw (Get-GraphErrorMessage $_)
        }

        # Graph only accepts the request (202); unpublishing finishes asynchronously
        foreach ($App in $AppsToUnpublish) {
            Write-Output "Unpublish requested for app: $($App.displayName) (ID: $($App.id))"
        }
    }
}
