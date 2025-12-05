---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# Invoke-CPCUnpublishCloudApp

## SYNOPSIS
UnPublishes a Cloud App to make it unavailable to users

## SYNTAX

### Id (Default)
```
Invoke-CPCUnpublishCloudApp -Id <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Name
```
Invoke-CPCUnpublishCloudApp -Name <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### InputObject
```
Invoke-CPCUnpublishCloudApp -InputObject <PSObject> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The function will unPublishes a Cloud App to make it unavailable to users

## EXAMPLES

### EXAMPLE 1
```
Invoke-CPCUnpublishCloudApp -Id "c1a2b3d4-e5f6-7g8h-9i0j-k1l2m3n4o5p6"
```

### EXAMPLE 2
```
Invoke-CPCUnpublishCloudApp -Name "Microsoft Access"
```

## PARAMETERS

### -Id
Enter the id of the Cloud App

```yaml
Type: String
Parameter Sets: Id
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
Enter the name of the Cloud App

```yaml
Type: String
Parameter Sets: Name
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
Cloud App object from Get-CloudApp

```yaml
Type: PSObject
Parameter Sets: InputObject
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
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
