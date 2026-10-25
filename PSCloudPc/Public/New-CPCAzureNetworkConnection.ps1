function New-CPCAzureNetworkConnection {
    <#
    .SYNOPSIS
    Adds a new Azure Network Connection
    .DESCRIPTION
    The function will add a new Azure Network Connection
    .PARAMETER Name
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
    Enter the Organizational Unit (OU) that you want to join the computer to. Required format: OU=OUName,DC=DomainName,DC=com. Optional; when omitted the computer account is created in the default OU of the domain.
    .EXAMPLE
    New-CPCAzureNetworkConnection -Name "AzureADJoin" -resourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01" -VirtualNetworkId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01" -subnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01/subnets/Subnet01" -subscriptionId "00000000-0000-0000-0000-000000000000"
    .EXAMPLE
    New-CPCAzureNetworkConnection -Name "HybridAzureADJoin" -resourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01" -VirtualNetworkId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01" -subnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01/subnets/Subnet01" -subscriptionId "00000000-0000-0000-0000-000000000000" -AdDomainName "contoso.com" -AdDomainUserName "admin@contoso.com" -AdDomainPassword (Read-Host -AsSecureString) -OrganizationalUnit "OU=OUName,DC=DomainName,DC=com"
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/virtualendpoint-post-onpremisesconnections?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'AzureADJoin', SupportsShouldProcess = $true)]
    param (
        
        [parameter(Mandatory, ParameterSetName = "AzureADJoin")]
        [parameter(Mandatory, ParameterSetName = "HybridAzureADJoin")]
        [Alias('DisplayName')]
        [string]$Name,
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
        [Parameter(ParameterSetName = "HybridAzureADJoin")]
        [string]$OrganizationalUnit
    )
    
    begin {
        Get-TokenValidity
        $CPCAzureNetworkConnection = Get-CPCAzureNetworkConnection -Name $Name -ErrorAction SilentlyContinue
        if ($CPCAzureNetworkConnection) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Azure Network Connection with name $Name already exists" -Category ResourceExists
        }
        switch ($PSCmdlet.ParameterSetName) {
            "AzureADJoin" {
                $ConnectionType = "azureADJoin"
            }
            "HybridAzureADJoin" {
                $ConnectionType = "hybridAzureADJoin"
            }
        }
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections"
    }
    Process {

        Write-Verbose "Parameterset: $($PSCmdlet.ParameterSetName)"

        # type is deprecated and stopped returning data on January 31, 2024; connectionType replaces it
        $params = @{
            displayName      = $Name
            connectionType   = $ConnectionType
            subscriptionId   = $SubscriptionId
            resourceGroupId  = $ResourceGroupId
            virtualNetworkId = $VirtualNetworkId
            subnetId         = $SubnetId
        }

        If ($PSCmdlet.ParameterSetName -eq 'HybridAzureADJoin') {
            Write-Verbose "Creating Hybrid Azure AD Join Azure Network Connection, adding domain join parameters"
            $params.adDomainName = $AdDomainName
            $params.adDomainUsername = $AdDomainUserName
            $params.adDomainPassword = $($AdDomainPassword | ConvertFrom-SecureString -AsPlainText)
            if ($PSBoundParameters.ContainsKey('OrganizationalUnit')) {
                $params.organizationalUnit = $OrganizationalUnit
            }
        }

        $body = $params | ConvertTo-Json -Depth 20

        # The body holds the domain join password, so it is not written to the verbose stream
        Write-Verbose "Creating Azure Network Connection '$Name' ($ConnectionType)"

        if ($PSCmdlet.ShouldProcess($Name, "Create Azure Network Connection ($ConnectionType)")) {
            try {
                $result = Invoke-WebRequest -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $body
                $result
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }
}