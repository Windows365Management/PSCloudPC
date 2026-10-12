function New-CPCAzureNetworkConnection {
    <#
    .SYNOPSIS
    Adds a new Azure Network Connection
    .DESCRIPTION
    The function will add a new Azure Network Connection (cloudPcOnPremisesConnection) for
    Microsoft Entra join (AzureADJoin parameter set) or Microsoft Entra hybrid join
    (HybridAzureADJoin parameter set). The join type is sent as connectionType; the deprecated
    type property is not sent.

    The AD domain password is converted to plain text only while the request body is built and
    is never written to verbose output.

    The command stops without creating a connection when an Azure Network Connection with the
    same display name already exists, or when the check for an existing connection fails.
    The created connection is returned without an adDomainPassword property.
    .PARAMETER DisplayName
    Enter the name of the Azure Network Connection
    .PARAMETER ResourceGroupId
    Enter the Resource Group Id. Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}
    .PARAMETER VirtualNetworkId
    Enter the Virtual Network Id. Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkName}
    .PARAMETER SubnetId
    Enter the Subnet Id. Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkName}/subnets/{subnetName}
    .PARAMETER SubscriptionId
    Enter the Subscription Id that's associated with your tenant
    .PARAMETER AdDomainName
    Enter the fully qualified domain name (FQDN) of the Active Directory domain you want to join.
    .PARAMETER AdDomainUserName
    Enter the user name of an account that has permission to join computers to the domain. Required format: admin@contoso.com
    .PARAMETER AdDomainPassword
    Enter the password of the account that has permission to join computers to the domain, as a SecureString.
    .PARAMETER OrganizationalUnit
    Enter the Organizational Unit (OU) that you want to join the computer to. Required format: OU=OUName,DC=DomainName,DC=com
    .EXAMPLE
    New-CPCAzureNetworkConnection -DisplayName "AzureADJoin" -ResourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01" -VirtualNetworkId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01" -SubnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01/subnets/Subnet01" -SubscriptionId "00000000-0000-0000-0000-000000000000"
    .EXAMPLE
    New-CPCAzureNetworkConnection -DisplayName "HybridAzureADJoin" -ResourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01" -VirtualNetworkId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01" -SubnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01/subnets/Subnet01" -SubscriptionId "00000000-0000-0000-0000-000000000000" -AdDomainName "contoso.com" -AdDomainUserName "admin@contoso.com" -AdDomainPassword (Read-Host -AsSecureString -Prompt "Domain join password") -OrganizationalUnit "OU=OUName,DC=DomainName,DC=com"
    .NOTES
    Required permission: CloudPC.ReadWrite.All (delegated; application permissions aren't supported)
    https://learn.microsoft.com/graph/api/virtualendpoint-post-onpremisesconnections?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'AzureADJoin', SupportsShouldProcess = $true)]
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
        # Stop when the lookup fails, so a failed lookup isn't treated as "doesn't exist"
        try {
            $CPCAzureNetworkConnection = @(Get-CPCAzureNetworkConnection -Name $DisplayName -ErrorAction Stop | Where-Object { $_.displayName -eq $DisplayName })
        }
        catch {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Could not check for an existing Azure Network Connection with name '$DisplayName': $(Get-GraphErrorMessage $_)" -Category InvalidOperation
        }
        if ($CPCAzureNetworkConnection.Count -gt 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Azure Network Connection with name '$DisplayName' already exists ($($CPCAzureNetworkConnection.id -join ', '))" -Category ResourceExists
        }
        # connectionType replaces the deprecated type property; send the documented enum values
        # https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta#cloudpconpremisesconnectiontype-values
        switch ($PSCmdlet.ParameterSetName) {
            "AzureADJoin" {
                $ConnectionType = "azureADJoin"
            }
            "HybridAzureADJoin" {
                $ConnectionType = "hybridAzureADJoin"
            }
        }
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections"
        Write-Verbose "URL: $url"
    }
    Process {

        Write-Verbose "Parameterset: $($PSCmdlet.ParameterSetName)"

        $params = @{
            displayName      = $DisplayName
            connectionType   = $ConnectionType
            subscriptionId   = $SubscriptionId
            resourceGroupId  = $ResourceGroupId
            virtualNetworkId = $VirtualNetworkId
            subnetId         = $SubnetId
        }

        If ($($PSCmdlet.ParameterSetName) -eq 'HybridAzureADJoin') {
            Write-Verbose "Creating Hybrid Azure AD Join Azure Network Connection, creating parameters"
            $params.adDomainName = $AdDomainName
            $params.adDomainUsername = $AdDomainUserName
            $params.organizationalUnit = $OrganizationalUnit
        }
        Else {
            Write-Verbose "Creating Azure AD Join Azure Network Connection, creating parameters"
        }

        # Log the body before the password is added, so the password never reaches verbose output
        Write-Verbose "Request body (adDomainPassword not shown): $($params | ConvertTo-Json -Depth 10)"

        if ($PSCmdlet.ShouldProcess($DisplayName, "Create Azure Network Connection ($ConnectionType)")) {
            try {
                If ($($PSCmdlet.ParameterSetName) -eq 'HybridAzureADJoin') {
                    # Graph expects the password in plain text; convert it only while building the body
                    $params.adDomainPassword = ConvertFrom-SecureString -SecureString $AdDomainPassword -AsPlainText
                }
                $body = $params | ConvertTo-Json -Depth 10

                $result = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $body -ErrorAction Stop

                # Never pass the password on, in case Graph ever returns it
                if ($null -ne $result -and $result -isnot [string]) {
                    $result | Select-Object -Property * -ExcludeProperty adDomainPassword
                }
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
            finally {
                $params.Remove("adDomainPassword")
                $body = $null
            }
        }
    }
}
