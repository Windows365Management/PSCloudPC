---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# Set-CPCProvisioningPolicyAssignment

## SYNOPSIS
Assign a Cloud PC Provisioning Policy to a group

## SYNTAX

```
Set-CPCProvisioningPolicyAssignment -Name <String> [-GroupName <String>] [-Force] [-ProvisioningType <String>]
 [-ServicePlanName <String>] [-AllotmentLicensesCount <Int64>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Assign a Cloud PC Provisioning Policy to a group

## EXAMPLES

### EXAMPLE 1
```
Set-CPCProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup"
```

### EXAMPLE 2
```
Set-CPCProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup" -Force (Removes existing assignments)
```

### EXAMPLE 3
```
Set-CPCProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup" -ProvisioningType "sharedByEntraGroup" -ServicePlanName "Cloud PC Frontline 2vCPU/8GB/128GB"
```

## PARAMETERS

### -Name
Name of the Cloud PC Provisioning Policy

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
If set, existing assignments will be removed and only the provided group will be assigned

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

### -ProvisioningType
Provisioning Type of the Cloud PC Provisioning Policy.
Valid values are: dedicated, sharedByUser, sharedByEntraGroup (Default: dedicated), if sharedByEntraGroup or sharedByUser is selected, only the provided group will be assigned, existing assignments will be removed

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Dedicated
Accept pipeline input: False
Accept wildcard characters: False
```

### -ServicePlanName
Name of the Service Plan to assign the policy to (required if ProvisioningType is sharedByEntraGroup or sharedByUser)

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

### -AllotmentLicensesCount
Number of licenses to allot for the Service Plan (default: 1)

```yaml
Type: Int64
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 1
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
