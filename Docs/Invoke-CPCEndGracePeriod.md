---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# Invoke-CPCEndGracePeriod

## SYNOPSIS
Function to end the grace period of a CloudPC

## SYNTAX

### Name (Default)
```
Invoke-CPCEndGracePeriod -Name <String> [-Force] [<CommonParameters>]
```

### All
```
Invoke-CPCEndGracePeriod [-All] [-Force] [<CommonParameters>]
```

## DESCRIPTION
Function to end the grace period of a CloudPC

## EXAMPLES

### EXAMPLE 1
```
Invoke-CPCEndGracePeriod -Name "CloudPC01"
```

### EXAMPLE 2
```
Invoke-CPCEndGracePeriod -All -Force
```

## PARAMETERS

### -Name
Name of the CloudPC to end the grace period of

```yaml
Type: String
Parameter Sets: Name
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -All
{{ Fill All Description }}

```yaml
Type: SwitchParameter
Parameter Sets: All
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Force parameter to end the grace period of all CloudPCs

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
