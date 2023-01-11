---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# New-CPCCustomImage

## SYNOPSIS
Adds a new Custom Image

## SYNTAX

```
New-CPCCustomImage [-Name <String>] -Version <String> -SourceImageResourceId <String> [<CommonParameters>]
```

## DESCRIPTION
The function will add a new Custom Image

## EXAMPLES

### EXAMPLE 1
```
New-CPCCustomImage -Name "CustomImage01" -Version "1.0" -SourceImageResourceId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/rg-azw365/providers/Microsoft.Compute/images/azw365-2021-03-01-01-00-00"
```

## PARAMETERS

### -Name
Enter the name of the Custom Image

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Version
Enter the version of the Custom Image

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

### -SourceImageResourceId
Enter the Source Image Resource Id from Azure

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
