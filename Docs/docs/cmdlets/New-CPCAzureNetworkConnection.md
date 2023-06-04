---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# New-CPCAzureNetworkConnection

## SYNOPSIS
Adds a new Provisioning Policy

## SYNTAX

### AzureADJoin (Default)
```
New-CPCAzureNetworkConnection -DisplayName <String> -ResourceGroupId <String> -VirtualNetworkId <String>
 -SubnetId <String> -SubscriptionId <String> [<CommonParameters>]
```

### HybridAzureADJoin
```
New-CPCAzureNetworkConnection -DisplayName <String> -ResourceGroupId <String> -VirtualNetworkId <String>
 -SubnetId <String> -SubscriptionId <String> -AdDomainName <String> -AdDomainUserName <String>
 -AdDomainPassword <SecureString> -OrganizationalUnit <String> [<CommonParameters>]
```

## DESCRIPTION
The function will add a new Provisioning Policy

## EXAMPLES

### EXAMPLE 1
```
New-CPCAzureNetworkConnection -name "AzureADJoin" -resourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01" -VirtualNetworkId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01" -subnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01/subnets/Subnet01" -subscriptionId "00000000-0000-0000-0000-000000000000"
```

### EXAMPLE 2
```
New-CPCAzureNetworkConnection -name "HybridAzureADJoin" -resourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01" -VirtualNetworkId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01" -subnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01/subnets/Subnet01" -subscriptionId "00000000-0000-0000-0000-000000000000" -AdDomainName "contoso.com" -AdDomainUserName "admin@contoso.com" -AdDomainPassword "Password01" -OrganizationalUnit "OU=OUName,DC=DomainName,DC=com"
```

## PARAMETERS

### -DisplayName
{{ Fill DisplayName Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ResourceGroupId
Enter the Resource Group Id.
Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -VirtualNetworkId
Enter the Virtual Network Id.
Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkName}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SubnetId
Enter the Subnet Id.
Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkName}/subnets/{subnetName}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SubscriptionId
Enter the Subscription Id that's associated with your tenant

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AdDomainName
Enter the fully qualified domain name (FQDN) of the Active Directory domain you want to join.

```yaml
Type: String
Parameter Sets: HybridAzureADJoin
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AdDomainUserName
Enter the user name of an account that has permission to join computers to the domain.
Required format: admin@contoso.com

```yaml
Type: String
Parameter Sets: HybridAzureADJoin
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AdDomainPassword
Enter the password of the account that has permission to join computers to the domain.

```yaml
Type: SecureString
Parameter Sets: HybridAzureADJoin
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OrganizationalUnit
Enter the Organizational Unit (OU) that you want to join the computer to.
Required format: OU=OUName,DC=DomainName,DC=com

```yaml
Type: String
Parameter Sets: HybridAzureADJoin
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
