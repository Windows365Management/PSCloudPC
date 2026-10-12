function Invoke-CPCRename {
    <#
        .SYNOPSIS
        Renames a Cloud PC
        .DESCRIPTION
        The function will rename a Cloud PC by updating its displayName via the
        Microsoft Graph Windows 365 rename API. The managed device name doesn't change.
        Identify the Cloud PC by its managed device name (-Name) or by its id (-CloudPCId).
        -CloudPCId also takes Cloud PC objects from the pipeline, such as the output of
        Get-CloudPC; every piped Cloud PC gets the same -NewDisplayName.
        The name must match the managed device name of exactly one Cloud PC; otherwise
        no request is sent. The command returns no output when the request is accepted.

        A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
        non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
        with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
        -ErrorVariable and $Error can also hold the underlying Graph errors.
        .PARAMETER Name
        Enter the current managed device name of the Cloud PC to rename. Use Get-CloudPC to find Cloud PC names.
        .PARAMETER NewDisplayName
        Enter the new display name to assign to the Cloud PC
        .PARAMETER CloudPCId
        The id of the Cloud PC. Accepts pipeline input by property name (id or CloudPCId), for example from Get-CloudPC.
        .EXAMPLE
        Invoke-CPCRename -Name "CPC-User-XXXX" -NewDisplayName "Marketing-CloudPC-01"
        .EXAMPLE
        Invoke-CPCRename -Name "CPC-User-XXXX" -NewDisplayName "Marketing-CloudPC-01" -WhatIf
        .EXAMPLE
        Invoke-CPCRename -CloudPCId "00000000-0000-0000-0000-000000000000" -NewDisplayName "Marketing-CloudPC-01"
        # Pipeline: Get-CloudPC -Name "CPC-User-XXXX" | Invoke-CPCRename -NewDisplayName "Marketing-CloudPC-01"
        .NOTES
        Required permission: CloudPC.ReadWrite.All (delegated or application).
        POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/rename with body { "displayName": "new name" }
        https://learn.microsoft.com/graph/api/cloudpc-rename?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NewDisplayName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]
        $CloudPCId
    )
    begin {

        Get-TokenValidity

        $params = @{
            displayName = $NewDisplayName
        } | ConvertTo-Json -Depth 10
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
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/rename"

        if ($PSCmdlet.ShouldProcess($targetName, "Rename Cloud PC display name to '$NewDisplayName'")) {
            Write-Verbose "Request: POST $url"
            try {
                $null = Invoke-RestMethod -Uri $url -Method POST -Headers $script:Authheader -Body $params -ContentType "application/json" -ErrorAction Stop
                Write-Verbose "Rename to '$NewDisplayName' requested for Cloud PC $targetName"
            }
            catch {
                Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Rename" -CloudPC $CloudPC
                return
            }
        }
    }
}
