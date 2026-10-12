Function Update-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Update a Cloud PC Provisioning Policy
    .DESCRIPTION
    Update a Cloud PC Provisioning Policy. Only the settings you pass are sent (a partial PATCH), so all other
    settings of the policy are kept. The current display name of the policy is always sent along unchanged.
    .PARAMETER Name
    Name of the Provisioning Policy to update. The name must match exactly one policy.
    .PARAMETER ImageType
    Type of image to use for the Cloud PC. Valid values are Custom or Gallery. Use it together with -ImageId.
    .PARAMETER ImageId
    Id of the image to use for the Cloud PC. This is the Id of the image in the gallery or the custom image
    .PARAMETER EnableSingleSignOn
    Enable Single Sign On for the Cloud PC
    .PARAMETER NamingTemplate
    Naming template for the Cloud PC
    .PARAMETER AzureNetworkConnection
    Name of one or more Azure Network Connections to use for the Cloud PC, in order of priority (It will replace current Azure Network Connection). Each name must match exactly one connection, and its health check must be passed, warning or informational.
    .PARAMETER DomainJoinType
    Domain join type for the Azure Network Connections (azureADJoin or hybridAzureADJoin). Only used with -AzureNetworkConnection. The connectionType of the connections is sent; when -DomainJoinType is passed and differs, the command stops.
    .EXAMPLE
    Update-CPCProvisioningPolicy -Name "Test-AzureADJoin" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc"
    .EXAMPLE
    Update-CPCProvisioningPolicy -Name "Test-AzureADJoin" -EnableSingleSignOn $true
    .EXAMPLE
    Update-CPCProvisioningPolicy -Name "Test-HybridADJoin" -AzureNetworkConnection "Azure Network Connection" -DomainJoinType "hybridAzureADJoin" -WhatIf
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/cloudpcprovisioningpolicy-update?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcdomainjoinconfiguration?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [ValidateSet("Custom","Gallery")]
        [parameter(Mandatory = $false)][string]$ImageType,

        [parameter(Mandatory = $false)][string]$ImageId,

        [parameter(Mandatory = $false)][bool]$EnableSingleSignOn,

        [parameter(Mandatory = $false)][string]$NamingTemplate,

        [parameter(Mandatory = $false)][object]$AzureNetworkConnection,

        [ValidateSet('azureADJoin', 'hybridAzureADJoin')]
        [string]$DomainJoinType = 'azureADJoin'
    )

    Begin {
        Get-TokenValidity

        If ($PSBoundParameters.ContainsKey("ImageType") -and [string]::IsNullOrWhiteSpace($ImageId)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "-ImageType can only be used together with -ImageId"
        }

        If ($PSBoundParameters.ContainsKey("DomainJoinType") -and -not $AzureNetworkConnection) {
            Write-Warning "-DomainJoinType is only used with -AzureNetworkConnection and is not sent"
        }

        # displayName isn't documented as filterable, so match on the client
        $listUrl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies?`$select=id,displayName"
        Write-Verbose "Looking up Provisioning Policy: $Name"
        try {
            # Prefer: include-unknown-enum-members, so evolvable enum values aren't returned as unknownFutureValue
            $Policy = @(Invoke-APIRequest -uri $listUrl -Token $script:Authtoken -Method GET -AdditionalHeaders @{ Prefer = "include-unknown-enum-members" } | Where-Object { $_.displayName -eq $Name })
        }
        catch {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message (Get-GraphErrorMessage $_) -Category InvalidOperation
        }

        If ($Policy.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Provisioning Policy found with name '$Name'" -Category ObjectNotFound
        }

        If ($Policy.Count -gt 1) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($Policy.Count) Provisioning Policies found with name '$Name' ($($Policy.id -join ', ')). The name must match exactly one policy"
        }

        $Policy = $Policy[0]

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($Policy.id)"

        Write-Verbose "Update url: $($url)"

        If ($AzureNetworkConnection) {
            # The connectionType from Graph is used; a passed -DomainJoinType must match it
            $RequestedJoinType = ""
            If ($PSBoundParameters.ContainsKey("DomainJoinType")) {
                $RequestedJoinType = $DomainJoinType
            }
            $domainJoinConfigurations = @(Resolve-CPCAzureNetworkConnection -Cmdlet $PSCmdlet -Name @($AzureNetworkConnection | ForEach-Object { [string]$_ }) -DomainJoinType $RequestedJoinType)
        }
    }

    Process {

        # The current displayName is sent along unchanged (as before); everything else only when passed, so Graph keeps the rest
        $params = @{
            displayName = $($Policy.displayName)
        }

        If ($ImageId) {
            $params.Add("imageId", $ImageId)
            If ($PSBoundParameters.ContainsKey("ImageType")) {
                $params.Add("imageType", $ImageType.ToLowerInvariant())
            }
        }

        If ($psboundparameters.ContainsKey("EnableSingleSignOn")) {
            $params.Add("enableSingleSignOn", $EnableSingleSignOn)
        }

        If ($NamingTemplate) {
            $params.Add("cloudPcNamingTemplate", $NamingTemplate)
        }

        If ($AzureNetworkConnection) {
            $params.Add("domainJoinConfigurations", $domainJoinConfigurations)
        }

        If ($params.Count -eq 1) {
            Write-Warning "Nothing to update for Provisioning Policy '$Name'. Pass at least one setting to change."
            return
        }

        $body = $params | ConvertTo-Json -Depth 10

        Write-Verbose "PATCH $url"
        Write-Verbose "Body: $($body)"

        If ($PSCmdlet.ShouldProcess($Name, "Update Provisioning Policy")) {
            try {
                Invoke-RestMethod -Uri $url -Method PATCH -Headers $script:Authheader -Body $body -ContentType "application/json" -ErrorAction Stop
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }
}
