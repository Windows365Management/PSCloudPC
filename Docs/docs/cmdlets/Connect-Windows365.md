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

```
Connect-Windows365 [[-Authtype] <String>] [[-ClientSecret] <String>] [-TenantID] <String>
 [[-ClientID] <String>] [<CommonParameters>]
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
Connect-Windows365 -Authtype ServicePrincipal -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientSecret 12345678-1234-1234-1234-123456789012
```

## PARAMETERS

### -Authtype
Type of Authentication to use. 
Interactive or ServicePrincipal

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Interactive
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientSecret
Client Secret for Service Principal Authentication

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

### -TenantID
Tenant ID for all Authentication types

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientID
Client ID for Service Principal Authentication

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
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
