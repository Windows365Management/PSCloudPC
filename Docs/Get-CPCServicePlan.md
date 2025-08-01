---
document type: cmdlet
external help file: PSCloudPC-Help.xml
HelpUri: ''
Locale: en-NL
Module Name: PSCloudPC
ms.date: 11/27/2024
PlatyPS schema version: 2024-05-01
title: Get-CPCServicePlan
---

# Get-CPCServicePlan

## SYNOPSIS

This function will return all currently available service plans

## SYNTAX

### Type

```
Get-CPCServicePlan [-ServicePlanName <string>] [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

This function will return all currently available service plans

## EXAMPLES

### EXAMPLE 1

Get-CPCServicePlans

### EXAMPLE 2

Get-CPCServicePlans -ServicePlanType "enterprise"

## PARAMETERS

### -ServicePlanName

{{ Fill ServicePlanName Description }}

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: Type
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

