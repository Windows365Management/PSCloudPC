---
document type: cmdlet
external help file: PSCloudPC-Help.xml
HelpUri: ''
Locale: en-NL
Module Name: PSCloudPC
ms.date: 11/27/2024
PlatyPS schema version: 2024-05-01
title: New-CPCCustomImage
---

# New-CPCCustomImage

## SYNOPSIS

Adds a new Custom Image

## SYNTAX

### Name (Default)

```
New-CPCCustomImage -Version <string> -SourceImageResourceId <string> [-Name <string>]
 [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

The function will add a new Custom Image

## EXAMPLES

### EXAMPLE 1

New-CPCCustomImage -Name "CustomImage01" -Version "1.0" -SourceImageResourceId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/rg-azw365/providers/Microsoft.Compute/images/azw365-2021-03-01-01-00-00"

## PARAMETERS

### -Name

Enter the name of the Custom Image

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: Name
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SourceImageResourceId

Enter the Source Image Resource Id from Azure

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

### -Version

Enter the version of the Custom Image

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

