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
 [-NamingTemplate <String>] [-ManagedBy <String>] [-ImageType <String>] -ImageId <String>
 -EnableSingleSignOn <Boolean> [-WindowsAutopatch <String>] [-Language <String>] [<CommonParameters>]
```

### AzureNetwork
```
New-CPCProvisioningPolicy -Name <String> [-Description <String>] [-ProvisioningType <String>]
 [-NamingTemplate <String>] -DomainJoinType <String> -AzureNetworkConnection <Object> [-ManagedBy <String>]
 [-ImageType <String>] -ImageId <String> -EnableSingleSignOn <Boolean> [-WindowsAutopatch <String>]
 [-Language <String>] [<CommonParameters>]
```

### MicrosoftHosted
```
New-CPCProvisioningPolicy -Name <String> [-Description <String>] [-ProvisioningType <String>]
 [-NamingTemplate <String>] -DomainJoinType <String> -RegionName <String> -RegionGroup <String>
 [-ManagedBy <String>] [-ImageType <String>] -ImageId <String> -EnableSingleSignOn <Boolean>
 [-WindowsAutopatch <String>] [-Language <String>] [<CommonParameters>]
```

## DESCRIPTION
The function will add a new Provisioning Policy

## EXAMPLES

### EXAMPLE 1
```
New-CPCProvisioningPolicy -Name "Test-AzureADJoin" -Description "Test-AzureADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -DomainJoinType "AzureADJoin" -EnableSingleSignOn $true -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US"
```

### EXAMPLE 2
```
New-CPCProvisioningPolicy -Name "Test-HybridADJoin" -Description "Test-HybridADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -DomainJoinType "hybridAzureADJoin" -EnableSingleSignOn $false -AzureNetworkConnection "Azure Network Connection" -Language "en-US"
```

### EXAMPLE 3
```
New-CPCProvisioningPolicy -Name "Test-Autopatch" -Description "Test-Autopatch" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true
```

### EXAMPLE 4
```
New-CPCProvisioningPolicy -Name "Test-NamingTemplate" -Description "Test-NamingTemplate" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true -NamingTemplate "%USERNAME:5%-%RAND:5%"
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

### -NamingTemplate
Apply device name template.
Create unique names for your devices.
Names must be between 5 and 15 characters, and can contain letters, numbers, hyphens, and underscores.
Names cannot include a blank space.
Use the %USERNAME:x% macro to add the first x letters of username.
Use the %RAND:y% macro to add a random alphanumeric string of length y, y must be 5 or more.
Names must contain a randomized string.

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

### -DomainJoinType
Enter the Domain Join Type for the Provisioning Policy (AzureADJoin or AzureADDomainJoin) (Default: AzureADJoin)

```yaml
Type: String
Parameter Sets: AzureNetwork, MicrosoftHosted
Aliases:

Required: True
Position: Named
Default value: AzureADJoin
Accept pipeline input: False
Accept wildcard characters: False
```

### -RegionName
Enter the Region Name for the Provisioning Policy

```yaml
Type: String
Parameter Sets: MicrosoftHosted
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
Parameter Sets: MicrosoftHosted
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AzureNetworkConnection
Enter the Azure Network Connection Name for the Provisioning Policy

```yaml
Type: Object
Parameter Sets: AzureNetwork
Aliases:

Required: True
Position: Named
Default value: None
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

### -ImageType
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

Required: True
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
