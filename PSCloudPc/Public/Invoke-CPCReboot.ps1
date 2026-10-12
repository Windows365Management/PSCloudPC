function Invoke-CPCReboot {
    <#
        .SYNOPSIS
        Reboots a CloudPC
        .DESCRIPTION
        The function will reboot a CloudPC. Identify the Cloud PC by its managed device name
        (-Name) or by its id (-CloudPCId). -CloudPCId also takes Cloud PC objects from the
        pipeline, such as the output of Get-CloudPC, and reboots each of them.
        The name must match the managed device name of exactly one Cloud PC; otherwise no
        request is sent. The command returns no output when the request is accepted.

        A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
        non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
        with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
        -ErrorVariable and $Error can also hold the underlying Graph errors.
        .PARAMETER Name
        Enter the managed device name of the CloudPC. Use Get-CloudPC to find Cloud PC names.
        .PARAMETER CloudPCId
        The id of the Cloud PC. Accepts pipeline input by property name (id or CloudPCId), for example from Get-CloudPC.
        .EXAMPLE
        Invoke-CPCReboot -Name "CPC-User-XXXX"
        .EXAMPLE
        Invoke-CPCReboot -Name "CPC-User-XXXX" -WhatIf
        .EXAMPLE
        Invoke-CPCReboot -CloudPCId "00000000-0000-0000-0000-000000000000"
        # Pipeline: Get-CloudPC | Where-Object { $_.status -eq "provisioned" } | Invoke-CPCReboot -WhatIf
        .NOTES
        Required permission: CloudPC.ReadWrite.All (delegated or application).
        POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/reboot (no request body)
        https://learn.microsoft.com/graph/api/cloudpc-reboot?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]
        $CloudPCId
    )
    begin {

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
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/reboot"

        if ($PSCmdlet.ShouldProcess($targetName, "Reboot Cloud PC")) {
            Write-Verbose "Request: POST $url"
            try {
                $null = Invoke-RestMethod -Uri $url -Method POST -Headers $script:Authheader -ErrorAction Stop
                Write-Verbose "Reboot requested for Cloud PC $targetName"
            }
            catch {
                Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Reboot" -CloudPC $CloudPC
                return
            }
        }
    }
}
