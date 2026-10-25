function Update-CPCAzureNetworkConnection {
    <#
    .SYNOPSIS
    Updates an existing Azure Network Connection
    .DESCRIPTION
    Updates an existing Azure Network Connection (cloudPcOnPremisesConnection) in the
    Cloud PC service via the Microsoft Graph beta API. Only the properties you supply
    are changed; omitted properties retain their current values.

    Target the connection by its display name (looked up via Get-CPCAzureNetworkConnection)
    or by its object ID directly via -ConnectionId.
    .PARAMETER Name
    Display name of the Azure Network Connection to update.
    Mutually exclusive with -ConnectionId.
    .PARAMETER ConnectionId
    Object ID (GUID) of the Azure Network Connection to update.
    Mutually exclusive with -Name.
    .PARAMETER DisplayName
    New display name for the Azure Network Connection.
    .PARAMETER SubscriptionId
    New Azure subscription ID to associate with the connection.
    .PARAMETER ResourceGroupId
    New resource group resource ID.
    Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}
    .PARAMETER VirtualNetworkId
    New virtual network resource ID.
    Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkName}
    .PARAMETER SubnetId
    New subnet resource ID.
    Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkName}/subnets/{subnetName}
    .PARAMETER AdDomainName
    New Active Directory domain FQDN. Applicable to Hybrid Azure AD Join connections only.
    .PARAMETER AdDomainUserName
    New AD domain join account UPN (e.g. admin@contoso.com). Hybrid Azure AD Join only.
    .PARAMETER AdDomainPassword
    New password for the AD domain join account as a SecureString. Hybrid Azure AD Join only.
    .PARAMETER OrganizationalUnit
    New OU distinguished name for computer accounts (e.g. OU=CloudPCs,DC=contoso,DC=com).
    Hybrid Azure AD Join only.
    .EXAMPLE
    Update-CPCAzureNetworkConnection -Name "Contoso Network" -SubnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG01/providers/Microsoft.Network/virtualNetworks/VNet01/subnets/NewSubnet01"
    .EXAMPLE
    Update-CPCAzureNetworkConnection -ConnectionId "00000000-0000-0000-0000-000000000000" -DisplayName "Contoso Network Updated"
    .EXAMPLE
    Update-CPCAzureNetworkConnection -Name "Contoso Hybrid Network" -AdDomainUserName "newadmin@contoso.com" -AdDomainPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) -WhatIf
    .NOTES
    Requires CloudPC.ReadWrite.All permission (delegated or application).
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpconpremisesconnection-update
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionId,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$ResourceGroupId,

        [Parameter(Mandatory = $false)]
        [string]$VirtualNetworkId,

        [Parameter(Mandatory = $false)]
        [string]$SubnetId,

        [Parameter(Mandatory = $false)]
        [string]$AdDomainName,

        [Parameter(Mandatory = $false)]
        [string]$AdDomainUserName,

        [Parameter(Mandatory = $false)]
        [securestring]$AdDomainPassword,

        [Parameter(Mandatory = $false)]
        [string]$OrganizationalUnit
    )

    Begin {
        Get-TokenValidity

        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $connection = @(Get-CPCAzureNetworkConnection -Name $Name)

            if ($connection.Count -eq 0) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Azure Network Connection found with name '$Name'. Use Get-CPCAzureNetworkConnection to verify the display name." -Category ObjectNotFound
            }

            if ($connection.Count -gt 1) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($connection.Count) Azure Network Connections found with name '$Name' ($($connection.id -join ', ')). Use -ConnectionId to select one."
            }

            $targetId   = $connection[0].id
            $targetName = $connection[0].displayName
        }
        else {
            $targetId   = $ConnectionId
            $targetName = $ConnectionId
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections/$targetId"
        Write-Verbose "Update url: $url"
    }

    Process {
        $params = @{}

        if ($PSBoundParameters.ContainsKey('DisplayName')) {
            $params['displayName'] = $DisplayName
        }
        if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
            $params['subscriptionId'] = $SubscriptionId
        }
        if ($PSBoundParameters.ContainsKey('ResourceGroupId')) {
            $params['resourceGroupId'] = $ResourceGroupId
        }
        if ($PSBoundParameters.ContainsKey('VirtualNetworkId')) {
            $params['virtualNetworkId'] = $VirtualNetworkId
        }
        if ($PSBoundParameters.ContainsKey('SubnetId')) {
            $params['subnetId'] = $SubnetId
        }
        if ($PSBoundParameters.ContainsKey('AdDomainName')) {
            $params['adDomainName'] = $AdDomainName
        }
        if ($PSBoundParameters.ContainsKey('AdDomainUserName')) {
            $params['adDomainUsername'] = $AdDomainUserName
        }
        if ($PSBoundParameters.ContainsKey('AdDomainPassword')) {
            # Graph expects the plain text password; without -AsPlainText an encrypted blob would be sent
            $params['adDomainPassword'] = $($AdDomainPassword | ConvertFrom-SecureString -AsPlainText)
        }
        if ($PSBoundParameters.ContainsKey('OrganizationalUnit')) {
            $params['organizationalUnit'] = $OrganizationalUnit
        }

        if ($params.Count -eq 0) {
            Write-Warning "No update properties were specified. Provide at least one parameter to update."
            return
        }

        $body = $params | ConvertTo-Json -Depth 10
        # The body can hold the domain join password, so only the property names are written to the verbose stream
        Write-Verbose "Updating properties: $($params.Keys -join ', ')"

        if ($PSCmdlet.ShouldProcess($targetName, 'Update Azure Network Connection')) {
            try {
                Write-Verbose "Updating Azure Network Connection '$targetName'"
                $result = Invoke-WebRequest -Uri $url -Method PATCH -Headers $script:authHeader -Body $body -ContentType "application/json"
                Write-Verbose "Result: $($result.Content)"
                return $result
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }
}
