---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# Update-CPCProvisioningPolicy

## SYNOPSIS
Update a Cloud PC Provisioning Policy

## SYNTAX

```
Update-CPCProvisioningPolicy -Name <String> [-ImageType <String>] [-ImageId <String>]
 [-EnableSingleSignOn <Boolean>] [<CommonParameters>]
```

## DESCRIPTION
Update a Cloud PC Provisioning Policy

## EXAMPLES

### EXAMPLE 1
```
Update-CPCProvisioningPolicy -Name "Test-AzureADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365"
```

### EXAMPLE 2
```
Update-CPCProvisioningPolicy -Name "Test-AzureADJoin" -EnableSingleSignOn $true
```

## PARAMETERS

### -Name
Name of the Provisioning Policy to update an image for example

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

### -ImageType
{{ Fill ImageType Description }}

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

### -ImageId
{{ Fill ImageId Description }}

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

### -EnableSingleSignOn
{{ Fill EnableSingleSignOn Description }}

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
