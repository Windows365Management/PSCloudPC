---
document type: cmdlet
external help file: PSCloudPC-Help.xml
HelpUri: ''
Locale: en-NL
Module Name: PSCloudPC
ms.date: 11/27/2024
PlatyPS schema version: 2024-05-01
title: Get-CPCRestorePoint
---

# Get-CPCRestorePoint

## SYNOPSIS

Get all Cloud PC restore points

## SYNTAX

### Name

```
Get-CPCRestorePoint -Name <string> [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

The function will restore a Cloud PC to a certain point in time

## EXAMPLES

### EXAMPLE 1

Get-CPCRestorePoint -Name "CloudPC01"

## PARAMETERS

### -Name

Enter the Cloud PC display name

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: Name
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

