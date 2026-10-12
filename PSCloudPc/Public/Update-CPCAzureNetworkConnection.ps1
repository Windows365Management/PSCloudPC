function Update-CPCAzureNetworkConnection {
    <#
    .SYNOPSIS
    Updates an existing Azure Network Connection
    .DESCRIPTION
    Updates an existing Azure Network Connection (cloudPcOnPremisesConnection) in the
    Cloud PC service via the Microsoft Graph API. Only the properties you supply
    are changed; omitted properties retain their current values.

    Target the connection by its display name (looked up via Get-CPCAzureNetworkConnection)
    or by its object ID directly via -ConnectionId. -Name must match exactly one connection;
    the command stops when it matches zero or more than one.

    The AD domain password is converted to plain text only while the request body is built and
    is never written to verbose output. The command stops when no update property is passed.
    The updated connection is returned without an adDomainPassword property.
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
    Update-CPCAzureNetworkConnection -Name "Contoso Hybrid Network" -AdDomainUserName "newadmin@contoso.com" -AdDomainPassword (Read-Host -AsSecureString -Prompt "Domain join password") -WhatIf
    .NOTES
    Required permission: CloudPC.ReadWrite.All (delegated; application permissions aren't supported)
    https://learn.microsoft.com/graph/api/cloudpconpremisesconnection-update?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
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

        $updateParameters = @('DisplayName', 'SubscriptionId', 'ResourceGroupId', 'VirtualNetworkId', 'SubnetId', 'AdDomainName', 'AdDomainUserName', 'AdDomainPassword', 'OrganizationalUnit')
        $boundParameters = @($PSBoundParameters.Keys)
        if (-not ($updateParameters | Where-Object { $_ -in $boundParameters })) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No update properties were specified. Provide at least one of: $($updateParameters -join ', ')"
        }

        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            try {
                $connection = @(Get-CPCAzureNetworkConnection -Name $Name -ErrorAction Stop | Where-Object { $_.displayName -eq $Name })
            }
            catch {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Could not look up Azure Network Connection '$Name': $(Get-GraphErrorMessage $_)" -Category InvalidOperation
            }

            if ($connection.Count -eq 0) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Azure Network Connection found with name '$Name'. Use Get-CPCAzureNetworkConnection to verify the display name." -Category ObjectNotFound
            }

            if ($connection.Count -gt 1) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($connection.Count) Azure Network Connections found with name '$Name' ($($connection.id -join ', ')). Use -ConnectionId to select one"
            }

            $targetId   = [string]$connection[0].id
            $targetName = $connection[0].displayName
        }
        else {
            $targetId   = $ConnectionId
            $targetName = $ConnectionId
        }

        if ([string]::IsNullOrWhiteSpace($targetId)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The Azure Network Connection '$targetName' has no id" -Category ObjectNotFound
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections/$([uri]::EscapeDataString($targetId))"
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
        if ($PSBoundParameters.ContainsKey('OrganizationalUnit')) {
            $params['organizationalUnit'] = $OrganizationalUnit
        }

        # Log the body before the password is added, so the password never reaches verbose output
        Write-Verbose "Body (adDomainPassword not shown): $($params | ConvertTo-Json -Depth 10)"

        if ($PSCmdlet.ShouldProcess($targetName, 'Update Azure Network Connection')) {
            try {
                if ($PSBoundParameters.ContainsKey('AdDomainPassword')) {
                    # Graph expects the password in plain text; convert it only while building the body
                    $params['adDomainPassword'] = ConvertFrom-SecureString -SecureString $AdDomainPassword -AsPlainText
                }
                $body = $params | ConvertTo-Json -Depth 10

                Write-Verbose "Updating Azure Network Connection '$targetName'"
                $result = Invoke-RestMethod -Uri $url -Method PATCH -Headers $script:Authheader -Body $body -ContentType "application/json" -ErrorAction Stop

                # Never pass the password on, in case Graph ever returns it
                if ($null -ne $result -and $result -isnot [string]) {
                    $result | Select-Object -Property * -ExcludeProperty adDomainPassword
                }
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
            finally {
                $params.Remove('adDomainPassword')
                $body = $null
            }
        }
    }
}
