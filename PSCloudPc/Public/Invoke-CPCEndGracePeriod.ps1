function Invoke-CPCEndGracePeriod {
    <#
        .SYNOPSIS
        Function to end the grace period of a CloudPC
        .DESCRIPTION
        Ends the grace period of one Cloud PC (-Name or -CloudPCId) or of every Cloud PC in its
        grace period (-All). Ending the grace period deprovisions the Cloud PC immediately; this
        can't be undone. -CloudPCId also takes Cloud PC objects from the pipeline, such as the
        output of Get-CloudPC.

        The command lists the Cloud PCs it will deprovision as a warning and asks for
        confirmation per Cloud PC twice: the standard -Confirm prompt and an extra prompt
        that -Force skips. To run without any prompt, use both -Force and -Confirm:$false.
        Use -WhatIf to see what would be deprovisioned without sending a request.

        -Name must match the managed device name of exactly one Cloud PC, and the Cloud PC
        (by name or id) must have status inGracePeriod; otherwise no request is sent for it.
        A problem with one Cloud PC (lookup, status or a failed Graph request) is reported as
        a non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
        with the next Cloud PC; use -ErrorAction Stop to stop at the first error. -ErrorVariable
        and $Error can also hold the underlying Graph errors. The command returns no output
        when the requests are accepted.
        .PARAMETER Name
        Managed device name of the Cloud PC to end the grace period of. Use Get-CloudPC to find Cloud PC names.
        .PARAMETER All
        End the grace period of every Cloud PC with status inGracePeriod.
        .PARAMETER Force
        Skips the extra confirmation prompt. The standard -Confirm prompt is only skipped with -Confirm:$false.
        .PARAMETER CloudPCId
        The id of the Cloud PC. Accepts pipeline input by property name (id or CloudPCId), for example from Get-CloudPC.
        .EXAMPLE
        Invoke-CPCEndGracePeriod -Name "CPC-User-XXXX"
        .EXAMPLE
        Invoke-CPCEndGracePeriod -All -WhatIf
        .EXAMPLE
        Invoke-CPCEndGracePeriod -All -Force -Confirm:$false
        .EXAMPLE
        Invoke-CPCEndGracePeriod -CloudPCId "00000000-0000-0000-0000-000000000000"
        # Pipeline: Get-CloudPC | Where-Object { $_.status -eq "inGracePeriod" -and $_.provisioningPolicyName -eq "Pilot" } | Invoke-CPCEndGracePeriod -WhatIf
        .NOTES
        Required permission: CloudPC.ReadWrite.All (delegated or application).
        POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/endGracePeriod (no request body), once per Cloud PC.
        https://learn.microsoft.com/graph/api/cloudpc-endgraceperiod?view=graph-rest-beta
    #>

    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [parameter(Mandatory, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All,

        [Parameter()][switch]$Force,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    Begin {
        Get-TokenValidity

        # Kept across process calls, so "Yes to All" / "No to All" covers every piped Cloud PC
        $yesToAll = $false
        $noToAll = $false

        If ($PSBoundParameters.ContainsKey('All')) {
            If (-not $All) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Use -Name or -CloudPCId to select one Cloud PC or -All to select every Cloud PC in its grace period"
            }

            $listUrl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs"
            Write-Verbose "Looking up every Cloud PC in its grace period"

            try {
                $AllCloudPCs = @(Invoke-APIRequest -uri $listUrl -Token $script:Authtoken -Method GET -ErrorAction Stop | Where-Object { $_.status -eq "inGracePeriod" })
            }
            catch {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Cloud PC lookup failed: $(Get-GraphErrorMessage $_)" -Category InvalidOperation
            }

            If ($AllCloudPCs.Count -eq 0) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Cloud PCs found in grace period" -Category ObjectNotFound
            }

            foreach ($CloudPC in $AllCloudPCs) {
                If ([string]::IsNullOrWhiteSpace([string]$CloudPC.id)) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "A Cloud PC in grace period has no id ($(Get-CPCCloudPCName -CloudPC $CloudPC)); no grace period was ended" -Category InvalidResult
                }
            }

            $labels = @($AllCloudPCs | ForEach-Object { Get-CPCCloudPCLabel -CloudPC $_ })
            Write-Warning "Ending the grace period deprovisions $($AllCloudPCs.Count) Cloud PC(s) immediately: $($labels -join ', ')"
        }
    }

    Process {
        If ($PSCmdlet.ParameterSetName -eq 'All') {
            $CloudPCs = $AllCloudPCs
        }
        Else {
            If ($PSCmdlet.ParameterSetName -eq 'Name') {
                $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -Name $Name
            }
            Else {
                $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -CloudPCId $CloudPCId
            }

            # The lookup wrote an error for this Cloud PC; continue with the next pipeline object
            if ($null -eq $CloudPC) {
                return
            }

            If ($CloudPC.status -ne "inGracePeriod") {
                Write-CPCError -Cmdlet $PSCmdlet -Message "Cloud PC $(Get-CPCCloudPCLabel -CloudPC $CloudPC) is not in its grace period (status: $($CloudPC.status))" -Category InvalidOperation -TargetObject $CloudPC.id
                return
            }

            $CloudPCs = @($CloudPC)
            Write-Warning "Ending the grace period deprovisions 1 Cloud PC(s) immediately: $(Get-CPCCloudPCLabel -CloudPC $CloudPC)"
        }

        foreach ($CloudPC in $CloudPCs) {
            $targetName = Get-CPCCloudPCLabel -CloudPC $CloudPC

            If ($PSCmdlet.ShouldProcess($targetName, "End grace period (deprovision Cloud PC)")) {
                If ($Force -or $PSCmdlet.ShouldContinue("End the grace period of Cloud PC $($targetName)? It is deprovisioned immediately.", "Confirm deprovision", [ref]$yesToAll, [ref]$noToAll)) {
                    $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/endGracePeriod"
                    Write-Verbose "Request: POST $url"

                    try {
                        $null = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ErrorAction Stop
                        Write-Verbose "End of grace period requested for Cloud PC $targetName"
                    }
                    catch {
                        # Report this Cloud PC and continue with the next one (-ErrorAction Stop stops here)
                        Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "End grace period" -CloudPC $CloudPC
                    }
                }
            }
        }
    }
}
