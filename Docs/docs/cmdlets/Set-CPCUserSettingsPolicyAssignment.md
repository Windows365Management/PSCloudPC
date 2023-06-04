---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# Set-CPCUserSettingsPolicyAssignment

## SYNOPSIS
Assign a Cloud PC User Settings Policy to a group

## SYNTAX

```
Set-CPCUserSettingsPolicyAssignment -Name <String> [-GroupName <String>] [-Force] [<CommonParameters>]
```

## DESCRIPTION
Assign a Cloud PC User Settings Policy to a group

## EXAMPLES

### EXAMPLE 1
```
Set-CPCUserSettingsPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup"
```

### EXAMPLE 2
```
Set-CPCUserSettingsPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup" -Force (Removes existing assignments)
```

## PARAMETERS

### -Name
Name of the Cloud PC User Settings Policy

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

### -GroupName
Name of the group to assign the policy to

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

### -Force
TODO: Add SupportsShouldProcess

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
