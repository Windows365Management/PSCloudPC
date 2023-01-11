---
external help file: PSCloudPC-help.xml
Module Name: PSCloudPC
online version:
schema: 2.0.0
---

# New-CPCProvisioningPolicy

## SYNOPSIS
Adds a new Provisioning Policy

## SYNTAX

### AzureADJoin (Default)
```
New-CPCProvisioningPolicy -Name <String> [-Description <String>] [-ProvisioningType <String>]
 [-ManagedBy <String>] [-imageType <String>] -ImageId <String> [-EnableSingleSignOn <Boolean>]
 [-WindowsAutopatch <String>] [-DomainJoinType <String>] -RegionName <String> -RegionGroup <String>
 [-Language <String>] [<CommonParameters>]
```

### AzureNetwork
```
New-CPCProvisioningPolicy -Name <String> [-Description <String>] [-ProvisioningType <String>]
 [-ManagedBy <String>] [-imageType <String>] -ImageId <String> [-EnableSingleSignOn <Boolean>]
 [-WindowsAutopatch <String>] [-DomainJoinType <String>] -OnPremisesConnectionId <String> [-Language <String>]
 [<CommonParameters>]
```

## DESCRIPTION
The function will add a new Provisioning Policy

## EXAMPLES

### EXAMPLE 1
```
New-CPCProvisioningPolicy -Name "Test-AzureADJoin" -Description "Test-AzureADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365-DomainJoinType "AzureADJoin" -EnableSingleSignOn $true -RegionName "West Europe" -RegionGroup "Europe" -Language "en-US"
```

### EXAMPLE 2
```
New-CPCProvisioningPolicy -Name "Test-HybridADJoin" -Description "Test-HybridADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -DomainJoinType "hybridAzureADJoin" -EnableSingleSignOn $false -OnPremisesConnectionId "00000000-0fe4-44cf-8ec0-24eebe498f25" -Language "en-US"
```

### EXAMPLE 3
```
New-CPCProvisioningPolicy -Name "Test-Autopatch" -Description "Test-Autopatch" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365 -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "West Europe" -RegionGroup "Europe" -Language "en-US" -EnableSingleSignOn $true
```

## PARAMETERS

### -Name
Enter the name of the Provisioning Policy

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

### -Description
Enter the description of the Provisioning Policy

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

### -ProvisioningType
Enter the Provisioning Type of the Provisioning Policy (dedicated or shared) (Default: dedicated)

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

### -ManagedBy
Enter the Managed By of the Provisioning Policy (Windows365 or Microsoft) (Default: Windows365)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Windows365
Accept pipeline input: False
Accept wildcard characters: False
```

### -imageType
Enter the image type of the Provisioning Policy (Custom or Gallery)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Gallery
Accept pipeline input: False
Accept wildcard characters: False
```

### -ImageId
Enter the Image Id of the Provisioning Policy (Info: Get-CPCGalleryImage or Get-CPCCustomImage)

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

### -WindowsAutopatch
{{ Fill WindowsAutopatch Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: NotManaged
Accept pipeline input: False
Accept wildcard characters: False
```

### -DomainJoinType
Enter the Domain Join Type for the Provisioning Policy (AzureADJoin or AzureADDomainJoin) (Default: AzureADJoin)

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

### -RegionName
Enter the Region Name for the Provisioning Policy

```yaml
Type: String
Parameter Sets: AzureADJoin
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RegionGroup
Enter the Region Group for the Provisioning Policy

```yaml
Type: String
Parameter Sets: AzureADJoin
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OnPremisesConnectionId
Enter the On Premises Connection Id (Azure Network Connection) for the Provisioning Policy

```yaml
Type: String
Parameter Sets: AzureNetwork
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Language
Enter the Language for the Provisioning Policy (Default: en-US)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: En-US
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
