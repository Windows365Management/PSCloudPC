---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# Get-CPCServicePlans

## SYNOPSIS
This function will return all currently available service plans

## SYNTAX

```
Get-CPCServicePlans [-ServicePlanType <String>] [<CommonParameters>]
```

## DESCRIPTION
This function will return all currently available service plans

## EXAMPLES

### EXAMPLE 1
```
Get-CPCServicePlans
```

### EXAMPLE 2
```
Get-CPCServicePlans -ServicePlanType "enterprise"
```

## PARAMETERS

### -ServicePlanType
Enter the type of service plan you want to retrieve.
Valid values are: "enterprise", "business"

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
