---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# Import-CPCProvisioningPolicy

## SYNOPSIS
Imports a Provisioning Policy from a JSON File

## SYNTAX

```
Import-CPCProvisioningPolicy -Inputfile <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The function will import a Provisioning Policy from a JSON File

## EXAMPLES

### EXAMPLE 1
```
Import-CPCProvisioningPolicy -Inputfile "C:\Temp\AzureADJoinPolicy.json"
```

## PARAMETERS

### -Inputfile
Enter the path to the JSON File

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

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
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
