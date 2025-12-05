---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# Get-CloudApp

## SYNOPSIS
Returns all Cloud PC Apps or Cloud PC Apps with a specific name

## SYNTAX

### All (Default)
```
Get-CloudApp [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Name
```
Get-CloudApp -Name <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Id
```
Get-CloudApp -Id <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The function will return all Cloud PC Apps or Cloud PC Apps with a specific name

## EXAMPLES

### EXAMPLE 1
```
Get-CloudApp -Name "Access"
```

### EXAMPLE 2
```
Get-CloudApp -Id "c1a2b3d4-e5f6-7g8h-9i0j-k1l2m3n4o5p6"
```

### EXAMPLE 3
```
Get-CloudApp
```

### EXAMPLE 4
```
Get-CloudApp | Where-Object { $_.appStatus -eq "published" }
```

## PARAMETERS

### -Name
Enter the name of the Cloud PC App

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

### -Id
Enter the id of the Cloud PC App

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
