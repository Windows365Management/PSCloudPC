---
document type: cmdlet
external help file: PSCloudPC-Help.xml
HelpUri: ''
Locale: en-NL
Module Name: PSCloudPC
ms.date: 11/27/2024
PlatyPS schema version: 2024-05-01
title: New-CPCProvisioningPolicy
---

# New-CPCProvisioningPolicy

## SYNOPSIS

Adds a new Provisioning Policy

## SYNTAX

### AzureADJoin (Default)

```
New-CPCProvisioningPolicy -Name <string> -ImageId <string> -EnableSingleSignOn <bool>
 [-Description <string>] [-ProvisioningType <string>] [-NamingTemplate <string>]
 [-ManagedBy <string>] [-ImageType <string>] [-WindowsAutopatch <string>] [-Language <string>]
 [-GroupName <string>] [-ServicePlanName <string>] [<CommonParameters>]
```

### AzureNetwork

```
New-CPCProvisioningPolicy -Name <string> -DomainJoinType <string> -AzureNetworkConnection <Object>
 -ImageId <string> -EnableSingleSignOn <bool> [-Description <string>] [-ProvisioningType <string>]
 [-NamingTemplate <string>] [-ManagedBy <string>] [-ImageType <string>] [-WindowsAutopatch <string>]
 [-Language <string>] [-GroupName <string>] [-ServicePlanName <string>] [<CommonParameters>]
```

### MicrosoftHosted

```
New-CPCProvisioningPolicy -Name <string> -DomainJoinType <string> -RegionName <string>
 -RegionGroup <string> -ImageId <string> -EnableSingleSignOn <bool> [-Description <string>]
 [-ProvisioningType <string>] [-NamingTemplate <string>] [-ManagedBy <string>] [-ImageType <string>]
 [-WindowsAutopatch <string>] [-Language <string>] [-GroupName <string>] [-ServicePlanName <string>]
 [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

The function will add a new Provisioning Policy

## EXAMPLES

### EXAMPLE 1

New-CPCProvisioningPolicy -Name "Test-AzureADJoin" -Description "Test-AzureADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -DomainJoinType "AzureADJoin" -EnableSingleSignOn $true -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US"

### EXAMPLE 2

New-CPCProvisioningPolicy -Name "Test-HybridADJoin" -Description "Test-HybridADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -DomainJoinType "hybridAzureADJoin" -EnableSingleSignOn $false -AzureNetworkConnection "Azure Network Connection" -Language "en-US"

### EXAMPLE 3

New-CPCProvisioningPolicy -Name "Test-Autopatch" -Description "Test-Autopatch" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true

### EXAMPLE 4

New-CPCProvisioningPolicy -Name "Test-NamingTemplate" -Description "Test-NamingTemplate" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true -NamingTemplate "%USERNAME:5%-%RAND:5%"

### EXAMPLE 5

New-CPCProvisioningPolicy -Name "Test-NamingTemplate2" -Description "Test-NamingTemplate" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true -NamingTemplate "%USERNAME:5%-%RAND:5%"  -GroupName "All Users" -ServicePlanName "Cloud PC Frontline 2vCPU/8GB/128GB"

## PARAMETERS

### -AzureNetworkConnection

Enter the Azure Network Connection Name for the Provisioning Policy

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: AzureNetwork
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Description

Enter the description of the Provisioning Policy

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -DomainJoinType

Enter the Domain Join Type for the Provisioning Policy (AzureADJoin or AzureADDomainJoin) (Default: AzureADJoin)

```yaml
Type: System.String
DefaultValue: azureADJoin
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: AzureNetwork
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: MicrosoftHosted
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -EnableSingleSignOn

{{ Fill EnableSingleSignOn Description }}

```yaml
Type: System.Boolean
DefaultValue: False
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -GroupName

Enter the Group Name for assigning the Provisioning Policy (mandatory for Frontline)

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ImageId

Enter the Image Id of the Provisioning Policy (Info: Get-CPCGalleryImage or Get-CPCCustomImage)

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ImageType

Enter the image type of the Provisioning Policy (Custom or Gallery)

```yaml
Type: System.String
DefaultValue: Gallery
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Language

Enter the Language for the Provisioning Policy (Default: en-US)

```yaml
Type: System.String
DefaultValue: en-US
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ManagedBy

Enter the Managed By of the Provisioning Policy (Windows365 or Microsoft) (Default: Windows365)

```yaml
Type: System.String
DefaultValue: Windows365
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Name

Enter the name of the Provisioning Policy

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -NamingTemplate

Apply device name template.
Create unique names for your devices.
Names must be between 5 and 15 characters, and can contain letters, numbers, hyphens, and underscores.
Names cannot include a blank space.
Use the %USERNAME:x% macro to add the first x letters of username.
Use the %RAND:y% macro to add a random alphanumeric string of length y, y must be 5 or more.
Names must contain a randomized string.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ProvisioningType

Enter the Provisioning Type of the Provisioning Policy (dedicated or shared) (Default: dedicated)

```yaml
Type: System.String
DefaultValue: dedicated
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RegionGroup

Enter the Region Group for the Provisioning Policy

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: MicrosoftHosted
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RegionName

Enter the Region Name for the Provisioning Policy

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: MicrosoftHosted
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ServicePlanName

Enter the Service Plan Name for assigning the Provisioning Policy (mandatory for Frontline)

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WindowsAutopatch

Enter the Windows Autopatch for the Provisioning Policy (notManaged or starterManaged) (Default: notManaged)

```yaml
Type: System.String
DefaultValue: notManaged
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
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

