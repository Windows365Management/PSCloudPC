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
Connect-Windows365 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ClientCertificate
```
Connect-Windows365 -TenantID <String> -ClientID <String> -ClientCertificate <X509Certificate2>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ClientSecret
```
Connect-Windows365 -TenantID <String> -ClientID <String> -ClientSecret <String>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### DeviceCode
```
Connect-Windows365 [-DeviceCode] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Token
```
Connect-Windows365 -Token <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Connect to Windows 365 via Powershell via Interactive Browser, Device Code, Service Principal or Access Token.

## EXAMPLES

### EXAMPLE 1
```
Connect-Windows365
```

### EXAMPLE 2
```
Connect-Windows365 -DeviceCode
```

### EXAMPLE 3
```
Connect-Windows365 -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientSecret 12345678-1234-1234-1234-123456789012
```

### EXAMPLE 4
```
Connect-Windows365 -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientCertificate "Certificate"
```

### EXAMPLE 5
```
Connect-Windows365 -Token "YourAccessToken"
```

## PARAMETERS

### -TenantID
Tenant ID for all Authentication types

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
Client Certificate for Service Principal Authentication, this must be the actual certificate not only the thumbprint

```yaml
Type: X509Certificate2
Parameter Sets: ClientCertificate
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeviceCode
Use Device Code Authentication (Switch to use Device Code Authentication)

```yaml
Type: SwitchParameter
Parameter Sets: DeviceCode
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Token
Use a Token for Authentication, this must be a valid access token for the Microsoft Graph API with CloudPC permissions

```yaml
Type: String
Parameter Sets: Token
Aliases:

Required: True
Position: Named
Default value: None
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
