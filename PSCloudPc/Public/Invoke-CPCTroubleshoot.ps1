function Invoke-CPCTroubleshoot {
    <#
        .SYNOPSIS
        Triggers a troubleshoot action on a Cloud PC
        .DESCRIPTION
        The function triggers the troubleshoot action on a specific Cloud PC. This initiates a
        health check and session host inspection on the target Cloud PC, helping administrators
        diagnose connectivity, configuration, and health issues without reprovisioning.
        Use Get-CloudPC to find Cloud PC names. The action returns 204 No Content on success.
        .PARAMETER Name
        Enter the display name of the Cloud PC to troubleshoot
        .EXAMPLE
        Invoke-CPCTroubleshoot -Name "CloudPC01"
        .EXAMPLE
        Invoke-CPCTroubleshoot -Name "CloudPC01" -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    Begin {
        Get-TokenValidity

        $CloudPC = Get-CloudPC -Name $Name

        if ($null -eq $CloudPC) {
            Write-Error "Cloud PC '$Name' not found"
            return
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/troubleshoot"
        Write-Verbose "Troubleshoot URL: $url"
    }

    Process {
        Write-Verbose "Triggering troubleshoot on Cloud PC '$($CloudPC.displayName)' (id: $($CloudPC.id))"

        if ($PSCmdlet.ShouldProcess($CloudPC.displayName, "Troubleshoot Cloud PC")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST
                Write-Output "Troubleshoot action triggered for Cloud PC '$($CloudPC.displayName)'"
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
