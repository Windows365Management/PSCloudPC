function Invoke-CPCResize {
    <#
        .SYNOPSIS
        Resizes a Cloud PC to a new service plan (vCPU and storage configuration)
        .DESCRIPTION
        The function upgrades or downgrades an existing Cloud PC to a configuration
        with a new virtual CPU (vCPU) and storage size by targeting a new service plan.
        The target service plan ID can be provided directly, or resolved by display name
        using the ServicePlanName parameter. Use Get-CPCServicePlan to discover available
        service plan IDs and their display names.

        Identify the Cloud PC by its managed device name (-Name) or by its id (-CloudPCId).
        -CloudPCId also takes Cloud PC objects from the pipeline, such as the output of
        Get-CloudPC; every piped Cloud PC is resized to the same service plan, which is
        looked up once.

        Resizing changes the Cloud PC, so the command asks for confirmation for each Cloud PC.
        Use -Confirm:$false to skip the prompt in automation. The name must match the managed
        device name of exactly one Cloud PC; otherwise no request is sent. The command
        returns no output when the request is accepted.

        A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
        non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
        with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
        -ErrorVariable and $Error can also hold the underlying Graph errors.
        .PARAMETER Name
        Enter the managed device name of the Cloud PC to resize. Use Get-CloudPC to find Cloud PC names.
        .PARAMETER ServicePlanId
        Enter the target service plan ID (GUID) to resize the Cloud PC to
        .PARAMETER ServicePlanName
        Enter the display name of the target service plan to resize the Cloud PC to.
        The function will resolve the ID automatically using Get-CPCServicePlan. The name must
        match exactly one service plan; otherwise no request is sent.
        .PARAMETER CloudPCId
        The id of the Cloud PC. Accepts pipeline input by property name (id or CloudPCId), for example from Get-CloudPC.
        .EXAMPLE
        Invoke-CPCResize -Name "CPC-User-XXXX" -ServicePlanId "00000000-0000-0000-0000-000000000000"
        .EXAMPLE
        Invoke-CPCResize -Name "CPC-User-XXXX" -ServicePlanName "Windows 365 Enterprise 4 vCPU, 16 GB, 256 GB"
        .EXAMPLE
        Invoke-CPCResize -Name "CPC-User-XXXX" -ServicePlanId "00000000-0000-0000-0000-000000000000" -Confirm:$false
        .EXAMPLE
        Invoke-CPCResize -CloudPCId "00000000-0000-0000-0000-000000000000" -ServicePlanName "Windows 365 Enterprise 4 vCPU, 16 GB, 256 GB"
        # Pipeline: Get-CloudPC | Where-Object { $_.provisioningPolicyName -eq "Developers" } | Invoke-CPCResize -ServicePlanName "Windows 365 Enterprise 4 vCPU, 16 GB, 256 GB" -WhatIf
        .NOTES
        Required permission: CloudPC.ReadWrite.All (delegated or application).
        POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/resize with body { "targetServicePlanId": "<service plan id>" }
        https://learn.microsoft.com/graph/api/cloudpc-resize?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CloudPCIdById')]
        [ValidateNotNullOrEmpty()]
        [string]$ServicePlanId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CloudPCIdByName')]
        [ValidateNotNullOrEmpty()]
        [string]$ServicePlanName,

        [Parameter(Mandatory = $true, ParameterSetName = 'CloudPCIdById', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'CloudPCIdByName', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    begin {
        Get-TokenValidity

        # Resolve the service plan once; it applies to every Cloud PC
        if ($PSBoundParameters.ContainsKey('ServicePlanName')) {
            Write-Verbose "Looking up service plan by name: $ServicePlanName"
            $ServicePlan = @(Get-CPCServicePlan -ServicePlanName $ServicePlanName)

            if ($ServicePlan.Count -eq 0) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Service plan '$ServicePlanName' not found. Use Get-CPCServicePlan to list available plans." -Category ObjectNotFound
            }

            if ($ServicePlan.Count -gt 1) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($ServicePlan.Count) service plans found with name '$ServicePlanName' ($($ServicePlan.id -join ', ')). Use -ServicePlanId to select one."
            }

            $ServicePlanId = [string]$ServicePlan[0].id
            Write-Verbose "Resolved service plan '$ServicePlanName' to id: $ServicePlanId"
        }

        $params = @{
            targetServicePlanId = $ServicePlanId
        } | ConvertTo-Json -Depth 10
    }

    Process {
        if ($PSCmdlet.ParameterSetName -in @('ById', 'ByName')) {
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
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/resize"

        if ($PSCmdlet.ShouldProcess($targetName, "Resize Cloud PC to service plan $ServicePlanId")) {
            Write-Verbose "Request: POST $url"
            try {
                $null = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params -ErrorAction Stop
                Write-Verbose "Resize to service plan '$ServicePlanId' requested for Cloud PC $targetName"
            }
            catch {
                Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Resize" -CloudPC $CloudPC
                return
            }
        }
    }
}
