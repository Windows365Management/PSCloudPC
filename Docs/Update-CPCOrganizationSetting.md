---
document type: cmdlet
external help file: PSCloudPC-Help.xml
HelpUri: ''
Locale: en-NL
Module Name: PSCloudPC
ms.date: 11/27/2024
PlatyPS schema version: 2024-05-01
title: Update-CPCOrganizationSetting
---

# Update-CPCOrganizationSetting

## SYNOPSIS

Update the Cloud PC organization settings

## SYNTAX

### __AllParameterSets

```
Update-CPCOrganizationSetting [[-OSVersion] <string>] [[-UserAccountType] <string>]
 [[-EnableMEMAutoEnroll] <bool>] [[-EnableSingleSignOn] <bool>] [[-WindowsSettings] <string>]
 [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Update the Cloud PC organization settings.
A tenant has only one cloudPcOrganizationSettings object.

## EXAMPLES

### EXAMPLE 1

Update-CPCOrganizationSetting -osVersion windows10 -userAccountType administrator -enableMEMAutoEnroll $true -enableSingleSignOn $true

## PARAMETERS

### -EnableMEMAutoEnroll

Specifies whether new Cloud PCs will be automatically enrolled in Microsoft Intune.
The default value is false.

```yaml
Type: System.Boolean
DefaultValue: False
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -EnableSingleSignOn

Specifies wether single sign-on is enabled for new Cloud PCs.
The default value is false.

```yaml
Type: System.Boolean
DefaultValue: False
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -OSVersion

The account type of the user on provisioned Cloud PCs.
The possible values are: standardUser, administrator

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -UserAccountType

The account type of the user on provisioned Cloud PCs.
The possible values are: standardUser, administrator

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WindowsSettings

{{ Fill WindowsSettings Description }}

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
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

