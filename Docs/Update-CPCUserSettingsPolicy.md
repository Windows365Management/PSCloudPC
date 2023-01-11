---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# Update-CPCUserSettingsPolicy

## SYNOPSIS
Updates a User Settings Policy in the Intune Cloud PC Service

## SYNTAX

```
Update-CPCUserSettingsPolicy -Name <String> [-LocalAdminEnabled <Boolean>] [-UserRestoreEnabled <Boolean>]
 [-UserRestoreFrequency <Object>] [<CommonParameters>]
```

## DESCRIPTION
Updates a User Settings Policy in the Intune Cloud PC Service

## EXAMPLES

### EXAMPLE 1
```
Update-CPCUserSettingsPolicy -Name "Your Settings Policy" -LocalAdminEnabled $true -UserRestoreEnabled $false -UserRestoreFrequency 6
```

## PARAMETERS

### -Name
Name of the User Settings Policy to update

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
Enable or disable local admin

```yaml
Type: Boolean
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
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserRestoreFrequency
Frequency of user restore points (4, 6, 12, 16, 24 hours)

```yaml
Type: Object
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
