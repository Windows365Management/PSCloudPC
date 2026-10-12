function Invoke-CPCTroubleshoot {
    <#
        .SYNOPSIS
        Triggers a troubleshoot action on a Cloud PC
        .DESCRIPTION
        The function triggers the troubleshoot action on a specific Cloud PC. This checks the
        health status of the Cloud PC and the session host, helping administrators diagnose
        connectivity, configuration, and health issues without reprovisioning.
        Identify the Cloud PC by its managed device name (-Name) or by its id (-CloudPCId).
        -CloudPCId also takes Cloud PC objects from the pipeline, such as the output of Get-CloudPC.
        The name must match the managed device name of exactly one Cloud PC; otherwise no
        request is sent. The command returns no output when the request is accepted.

        A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
        non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
        with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
        -ErrorVariable and $Error can also hold the underlying Graph errors.
        .PARAMETER Name
        Enter the managed device name of the Cloud PC to troubleshoot. Use Get-CloudPC to find Cloud PC names.
        .PARAMETER CloudPCId
        The id of the Cloud PC. Accepts pipeline input by property name (id or CloudPCId), for example from Get-CloudPC.
        .EXAMPLE
        Invoke-CPCTroubleshoot -Name "CPC-User-XXXX"
        .EXAMPLE
        Invoke-CPCTroubleshoot -Name "CPC-User-XXXX" -WhatIf
        .EXAMPLE
        Invoke-CPCTroubleshoot -CloudPCId "00000000-0000-0000-0000-000000000000"
        # Pipeline: Get-CloudPC | Where-Object { $_.status -eq "provisioned" } | Invoke-CPCTroubleshoot
        .NOTES
        Required permission: CloudPC.ReadWrite.All (delegated or application).
        POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/troubleshoot (no request body)
        https://learn.microsoft.com/graph/api/cloudpc-troubleshoot?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    Begin {
        Get-TokenValidity
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -Name $Name
        }
        else {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -CloudPCId $CloudPCId
        }

        # The lookup wrote an error for this Cloud PC; continue with the next pipeline object
        if ($null -eq $CloudPC) {
            return
        }

        $targetName = Get-CPCCloudPCLabel -CloudPC $CloudPC
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/troubleshoot"

        if ($PSCmdlet.ShouldProcess($targetName, "Troubleshoot Cloud PC")) {
            Write-Verbose "Request: POST $url"
            try {
                $null = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ErrorAction Stop
                Write-Verbose "Troubleshoot requested for Cloud PC $targetName"
            }
            catch {
                Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Troubleshoot" -CloudPC $CloudPC
                return
            }
        }
    }
}
