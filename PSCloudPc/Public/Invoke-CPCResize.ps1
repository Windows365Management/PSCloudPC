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
        .PARAMETER Name
        Enter the display name of the Cloud PC to resize
        .PARAMETER ServicePlanId
        Enter the target service plan ID (GUID) to resize the Cloud PC to
        .PARAMETER ServicePlanName
        Enter the display name of the target service plan to resize the Cloud PC to.
        The function will resolve the ID automatically using Get-CPCServicePlan.
        .EXAMPLE
        Invoke-CPCResize -Name "CloudPC01" -ServicePlanId "30d0e128-de93-41dc-89ec-33d84bb662a0"
        .EXAMPLE
        Invoke-CPCResize -Name "CloudPC01" -ServicePlanName "Windows 365 Enterprise 4 vCPU, 16 GB, 256 GB"
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [string]$ServicePlanId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string]$ServicePlanName
    )

    begin {
        Get-TokenValidity

        $CloudPC = Get-CloudPC -Name $Name

        if ($null -eq $CloudPC) {
            Write-Error "Cloud PC '$Name' not found"
            break
        }

        if ($PsCmdlet.ParameterSetName -eq 'ByName') {
            Write-Verbose "Looking up service plan by name: $ServicePlanName"
            $ServicePlan = Get-CPCServicePlan -ServicePlanName $ServicePlanName

            if ($null -eq $ServicePlan) {
                Write-Error "Service plan '$ServicePlanName' not found. Use Get-CPCServicePlan to list available plans."
                break
            }

            $ServicePlanId = $ServicePlan.id
            Write-Verbose "Resolved service plan '$ServicePlanName' to id: $ServicePlanId"
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/resize"
        Write-Verbose "Resize URL: $url"
    }

    Process {
        $params = @{
            targetServicePlanId = $ServicePlanId
        } | ConvertTo-Json -Depth 10

        Write-Verbose "Resizing Cloud PC '$($CloudPC.displayName)' (id: $($CloudPC.id)) to service plan id: $ServicePlanId"

        if ($PSCmdlet.ShouldProcess($CloudPC.displayName, "Resize Cloud PC to service plan $ServicePlanId")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params
                Write-Output "Cloud PC '$($CloudPC.displayName)' resize initiated to service plan '$ServicePlanId'"
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
