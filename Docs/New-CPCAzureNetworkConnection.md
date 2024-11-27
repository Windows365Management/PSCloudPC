---
document type: cmdlet
external help file: PSCloudPC-Help.xml
HelpUri: ''
Locale: en-NL
Module Name: PSCloudPC
ms.date: 11/27/2024
PlatyPS schema version: 2024-05-01
title: New-CPCAzureNetworkConnection
---

# New-CPCAzureNetworkConnection

## SYNOPSIS

Adds a new Provisioning Policy

## SYNTAX

### AzureADJoin (Default)

```
New-CPCAzureNetworkConnection -DisplayName <string> -ResourceGroupId <string>
 -VirtualNetworkId <string> -SubnetId <string> -SubscriptionId <string> [<CommonParameters>]
```

### HybridAzureADJoin

```
New-CPCAzureNetworkConnection -DisplayName <string> -ResourceGroupId <string>
 -VirtualNetworkId <string> -SubnetId <string> -SubscriptionId <string> -AdDomainName <string>
 -AdDomainUserName <string> -AdDomainPassword <securestring> -OrganizationalUnit <string>
 [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

The function will add a new Provisioning Policy

## EXAMPLES

### EXAMPLE 1

New-CPCAzureNetworkConnection -name "AzureADJoin" -resourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01" -VirtualNetworkId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01" -subnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01/subnets/Subnet01" -subscriptionId "00000000-0000-0000-0000-000000000000"

### EXAMPLE 2

New-CPCAzureNetworkConnection -name "HybridAzureADJoin" -resourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01" -VirtualNetworkId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01" -subnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ResourceGroup01/providers/Microsoft.Network/virtualNetworks/VirtualNetwork01/subnets/Subnet01" -subscriptionId "00000000-0000-0000-0000-000000000000" -AdDomainName "contoso.com" -AdDomainUserName "admin@contoso.com" -AdDomainPassword "Password01" -OrganizationalUnit "OU=OUName,DC=DomainName,DC=com"

## PARAMETERS

### -AdDomainName

Enter the fully qualified domain name (FQDN) of the Active Directory domain you want to join.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: HybridAzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -AdDomainPassword

Enter the password of the account that has permission to join computers to the domain.

```yaml
Type: System.Security.SecureString
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: HybridAzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -AdDomainUserName

Enter the user name of an account that has permission to join computers to the domain.
Required format: admin@contoso.com

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: HybridAzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -DisplayName

{{ Fill DisplayName Description }}

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: HybridAzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: AzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -OrganizationalUnit

Enter the Organizational Unit (OU) that you want to join the computer to.
Required format: OU=OUName,DC=DomainName,DC=com

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: HybridAzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ResourceGroupId

Enter the Resource Group Id.
Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: HybridAzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: AzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SubnetId

Enter the Subnet Id.
Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkName}/subnets/{subnetName}

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: HybridAzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: AzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SubscriptionId

Enter the Subscription Id that's associated with your tenant

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: HybridAzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: AzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -VirtualNetworkId

Enter the Virtual Network Id.
Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkName}

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: HybridAzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: AzureADJoin
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

