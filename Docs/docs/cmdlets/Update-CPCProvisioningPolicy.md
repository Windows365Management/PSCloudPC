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
 [-EnableSingleSignOn <Boolean>] [-NamingTemplate <String>] [-AzureNetworkConnection <Object>]
 [-DomainJoinType <String>] [<CommonParameters>]
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
Type of image to use for the Cloud PC.
Valid values are Custom or Gallery

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
Id of the image to use for the Cloud PC.
This is the Id of the image in the gallery or the custom image

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
Enable Single Sign On for the Cloud PC

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

### -NamingTemplate
Naming template for the Cloud PC

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

### -AzureNetworkConnection
Azure Network Connection to use for the Cloud PC (It will replace current Azure Network Connection)

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

### -DomainJoinType
{{ Fill DomainJoinType Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: AzureADJoin
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
