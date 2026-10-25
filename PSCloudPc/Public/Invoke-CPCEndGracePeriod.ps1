function Invoke-CPCEndGracePeriod {
    <#
        .SYNOPSIS
        Function to end the grace period of a CloudPC
        .DESCRIPTION
        Function to end the grace period of a CloudPC
        .PARAMETER name
        Name of the CloudPC to end the grace period of
        .PARAMETER All
        End the grace period of every CloudPC that is in its grace period
        .PARAMETER Force
        End the grace period without asking for confirmation (same as -Confirm:$false)
        .EXAMPLE
        Invoke-CPCEndGracePeriod -Name "CloudPC01"
        .EXAMPLE
        Invoke-CPCEndGracePeriod -All -Force
        .EXAMPLE
        Invoke-CPCEndGracePeriod -All -WhatIf
        .NOTES
        Required permission: CloudPC.ReadWrite.All
        https://learn.microsoft.com/graph/api/cloudpc-endgraceperiod?view=graph-rest-beta
    #>

    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [parameter(Mandatory, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All,

        [Parameter()][switch]$Force
    )
        
    Begin {
        Get-TokenValidity

        # -Force skips the confirmation prompt, as before; -WhatIf still works
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }
    }
        
    Process {
        switch ($PsCmdlet.ParameterSetName) {
            Name {  
                $CloudPCs = @(Get-CloudPC -name $Name | Where-Object { $_.status -eq "inGracePeriod" })
                Write-Verbose "Getting Single CloudPC inGracePeriod: $($CloudPCs.managedDeviceName)"

                If ($CloudPCs.Count -eq 0) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No CloudPC found in grace period with name $Name" -Category ObjectNotFound
                }
            }

            All {
                $CloudPCs = @(Get-CloudPC | Where-Object { $_.status -eq "inGracePeriod" })
                Write-Verbose "Getting every CloudPC inGracePeriod: $($CloudPCs.managedDeviceName)"

                If ($CloudPCs.Count -eq 0) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No CloudPC found in grace period" -Category ObjectNotFound
                }
            }
        }

        Write-Verbose "$($CloudPCs.Count) CloudPC(s) found in grace period"

        foreach ($CloudPC in $CloudPCs) {
            $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/endGracePeriod"

            Write-Verbose "End Grace Period $($CloudPC.managedDeviceName) url: $($url)"

            if ($PSCmdlet.ShouldProcess($CloudPC.managedDeviceName, "End grace period (the Cloud PC is deprovisioned or reprovisioned)")) {
                try {
                    # Graph returns 204 No Content
                    $null = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST

                    Write-Output "End Grace Period $($CloudPC.managedDeviceName)"
                }
                catch {
                    Throw (Get-GraphErrorMessage $_)
                }
            }
        }
    }
}
