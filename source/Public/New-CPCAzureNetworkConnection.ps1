function New-CPCAzureNetworkConnection {
    <#
    .SYNOPSIS
    Adds a new Provisioning Policy
    .DESCRIPTION
    The function will add a new Provisioning Policy
    .PARAMETER name
    Enter the name of the Azure Network Connection
    .PARAMETER resourceGroupId
    Enter the Resource Group Id. Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}
    .PARAMETER VirtualNetworkId
    Enter the Virtual Network Id. Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkName}
    .PARAMETER subnetId
    Enter the Subnet Id. Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkName}/subnets/{subnetName}
    .PARAMETER subscriptionId
    Enter the Subscription Id that's associated with your tenant
    .PARAMETER AdDomainName
    Enter the fully qualified domain name (FQDN) of the Active Directory domain you want to join.
    .PARAMETER AdDomainUserName
    Enter the user name of an account that has permission to join computers to the domain. Required format: admin@contoso.com
    .PARAMETER AdDomainPassword
    Enter the password of the account that has permission to join computers to the domain.
    .PARAMETER OrganizationalUnit
    Enter the Organizational Unit (OU) that you want to join the computer to. Required format: OU=OUName,DC=DomainName,DC=com
    .EXAMPLE
    New-CPCAzureNetworkConnection -name "AzureADJoin" -resourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01" -VirtualNetworkId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01" -subnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01/subnets/Subnet01" -subscriptionId "00000000-0000-0000-0000-000000000000"
    .EXAMPLE
    New-CPCAzureNetworkConnection -name "HybridAzureADJoin" -resourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01" -VirtualNetworkId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01" -subnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01/subnets/Subnet01" -subscriptionId "00000000-0000-0000-0000-000000000000" -AdDomainName "contoso.com" -AdDomainUserName "admin@contoso.com" -AdDomainPassword "Password01" -OrganizationalUnit "OU=OUName,DC=DomainName,DC=com"
    #>
    [CmdletBinding(DefaultParameterSetName = 'AzureADJoin')]
    param (
        
        [parameter(Mandatory, ParameterSetName = "AzureADJoin")]
        [parameter(Mandatory, ParameterSetName = "HybridAzureADJoin")]
        [string]$DisplayName,
        [parameter(Mandatory, ParameterSetName = "AzureADJoin")]
        [parameter(Mandatory, ParameterSetName = "HybridAzureADJoin")]
        [string]$ResourceGroupId,
        [parameter(Mandatory, ParameterSetName = "AzureADJoin")]
        [parameter(Mandatory, ParameterSetName = "HybridAzureADJoin")]
        [string]$VirtualNetworkId,
        [parameter(Mandatory, ParameterSetName = "AzureADJoin")]
        [parameter(Mandatory, ParameterSetName = "HybridAzureADJoin")]
        [string]$SubnetId,
        [parameter(Mandatory, ParameterSetName = "AzureADJoin")]
        [parameter(Mandatory, ParameterSetName = "HybridAzureADJoin")]
        [string]$SubscriptionId,
        [Parameter(Mandatory, ParameterSetName = "HybridAzureADJoin")]
        [string]$AdDomainName,
        [Parameter(Mandatory, ParameterSetName = "HybridAzureADJoin")]
        [string]$AdDomainUserName,
        [Parameter(Mandatory, ParameterSetName = "HybridAzureADJoin")]
        [securestring]$AdDomainPassword,
        [Parameter(Mandatory, ParameterSetName = "HybridAzureADJoin")]
        [string]$OrganizationalUnit
    )
    
    begin {
        Get-TokenValidity
        $CPCAzureNetworkConnection = Get-CPCAzureNetworkConnection -Name $DisplayName -ErrorAction SilentlyContinue
        if ($CPCAzureNetworkConnection) {
            Write-Error "Azure Network Connection with name $Name already exists"
            break
        }
        switch ($PSCmdlet.ParameterSetName) {
            "AzureADJoin" {
                $DomainJoinType = "AzureADJoin"
            }
            "HybridAzureADJoin" {
                $DomainJoinType = "HybridAzureADJoin"
            }
        }
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections"
    }
    Process {

        Write-Verbose "Parameterset: $($PSCmdlet.ParameterSetName)"

        If ($($PSCmdlet.ParameterSetName) -eq 'HybridAzureADJoin') {
            Write-Verbose "Creating Hybrid Azure AD Join Azure Network Connection, creating parameters"
            $params = @{
                DisplayName        = $DisplayName
                SubscriptionId     = $SubscriptionId
                Type               = $DomainJoinType
                SubscriptionName   = $SubscriptionName
                AdDomainName       = $AdDomainName
                AdDomainUsername   = $AdDomainUsername
                AdDomainPassword   = $($AdDomainPassword | ConvertFrom-SecureString)
                OrganizationalUnit = $OrganizationalUnit
                ResourceGroupId    = $ResourceGroupId
                VirtualNetworkId   = $VirtualNetworkId
                SubnetId           = $SubnetId
            }
        }
        Else {
            Write-Verbose "Creating Azure AD Join Azure Network Connection, creating parameters"
            $params = @{
                DisplayName        = $DisplayName
                Type               = $DomainJoinType
                SubscriptionId     = $SubscriptionId
                ResourceGroupId    = $ResourceGroupId
                VirtualNetworkId   = $VirtualNetworkId
                SubnetId           = $SubnetId
            }
        }

        Write-verbose $params
        $body = $params | ConvertTo-Json -Depth 20
        
        Write-Verbose $body
        try {
            $result = Invoke-WebRequest -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $body
            $result
        }
        catch {
            Throw $_.Exception
        }        
    }
}