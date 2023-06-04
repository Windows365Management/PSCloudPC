---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# New-CPCUserSettingsPolicy

## SYNOPSIS
Creates new Cloud PC User Settings Policy

## SYNTAX

```
New-CPCUserSettingsPolicy -Name <String> [-LocalAdminEnabled <String>] [-UserRestoreEnabled <String>]
 [-FrequencyInHours <Object>] [<CommonParameters>]
```

## DESCRIPTION
The function will create a new Cloud PC User Settings Policy

## EXAMPLES

### EXAMPLE 1
```
New-CPCUserSettingsPolicy -Name "Cloud PC User Settings Policy" -LocalAdminEnabled $true -UserRestoreEnabled $true -FrequencyInHours 6
```

## PARAMETERS

### -Name
{{ Fill Name Description }}

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

### -LocalAdminEnabled
Enable or disable local admin permissions

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserRestoreEnabled
Enable or disable user restore

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### -FrequencyInHours
Set the frequency of restore points in hours

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 6
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
