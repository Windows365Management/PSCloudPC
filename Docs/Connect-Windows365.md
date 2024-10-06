---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# Connect-Windows365

## SYNOPSIS
Connect to Windows 365 via Powershell

## SYNTAX

### Interactive (Default)
```
Connect-Windows365 -TenantID <String> [-DeviceCode <Boolean>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### ClientCertificate
```
Connect-Windows365 -TenantID <String> -ClientID <String> -ClientCertificate <String> [-DeviceCode <Boolean>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ClientSecret
```
Connect-Windows365 -TenantID <String> -ClientID <String> -ClientSecret <String> [-DeviceCode <Boolean>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### DeviceCode
```
Connect-Windows365 -TenantID <String> [-DeviceCode <Boolean>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Connect to Windows 365 via Powershell via Interactive Browser or Service Principal

## EXAMPLES

### EXAMPLE 1
```
Connect-Windows365 -TenantID contoso.onmicrosoft.com
```

### EXAMPLE 2
```
Connect-Windows365 -TenantID contoso.onmicrosoft.com -DeviceCode:$true
```

### EXAMPLE 3
```
Connect-Windows365 -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientSecret 12345678-1234-1234-1234-123456789012
```

### EXAMPLE 4
```
Connect-Windows365 -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientCertificate "THUMBPRINT"
```

## PARAMETERS

### -TenantID
Tenant ID for all Authentication types

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

### -ClientID
Client ID for Service Principal Authentication

```yaml
Type: String
Parameter Sets: ClientCertificate, ClientSecret
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientSecret
Client Secret for Service Principal Authentication

```yaml
Type: String
Parameter Sets: ClientSecret
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientCertificate
Client Certificate for Service Principal Authentication (THUMBPRINT)

```yaml
Type: String
Parameter Sets: ClientCertificate
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeviceCode
{{ Fill DeviceCode Description }}

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
