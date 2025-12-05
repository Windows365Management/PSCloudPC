---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# Update-CPCOrganizationSettings

## SYNOPSIS
Update the Cloud PC organization settings

## SYNTAX

```
Update-CPCOrganizationSettings [[-OSVersion] <String>] [[-UserAccountType] <String>]
 [[-EnableMEMAutoEnroll] <Boolean>] [[-EnableSingleSignOn] <Boolean>] [[-WindowsSettings] <String>]
 [<CommonParameters>]
```

## DESCRIPTION
Update the Cloud PC organization settings.
A tenant has only one cloudPcOrganizationSettings object.

## EXAMPLES

### EXAMPLE 1
```
Update-CPCOrganizationSettings -osVersion windows10 -userAccountType administrator -enableMEMAutoEnroll $true -enableSingleSignOn $true
```

## PARAMETERS

### -OSVersion
The account type of the user on provisioned Cloud PCs.
The possible values are: standardUser, administrator

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserAccountType
The account type of the user on provisioned Cloud PCs.
The possible values are: standardUser, administrator

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnableMEMAutoEnroll
Specifies whether new Cloud PCs will be automatically enrolled in Microsoft Intune.
The default value is false.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnableSingleSignOn
Specifies wether single sign-on is enabled for new Cloud PCs.
The default value is false.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WindowsSettings
{{ Fill WindowsSettings Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
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
