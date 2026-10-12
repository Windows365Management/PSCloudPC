function Get-CloudPC {
    <#
        .SYNOPSIS
        Returns all CloudPC's or CloudPC's with a specific name
        .DESCRIPTION
        The function will return all CloudPC's or CloudPC's with a specific managed device name.
        When the tenant has no Cloud PCs, nothing is returned. When -Name matches no Cloud PC,
        a non-terminating error is written.
        A Cloud PC that is still provisioning has no managed device name yet, so -Name can't
        find it; run Get-CloudPC without -Name to see it.

        Each Cloud PC is returned with these properties: Name, id, managedDeviceName, managedDeviceId,
        displayName, userPrincipalName, status, provisioningPolicyName, imageDisplayName,
        lastModifiedDateTime, servicePlanType and servicePlanName.
        Name is the managed device name (the Intune device name) that -Name expects; it is empty while
        the Cloud PC is provisioning and for Windows 365 Business Cloud PCs; use id then.
        lastModifiedDateTime and servicePlanType use the Graph casing (they were lastmodifiedDateTime and
        serviceplanType); PowerShell property names are case-insensitive, so existing scripts keep working.
        .PARAMETER name
        Enter the managed device name of the CloudPC
        .EXAMPLE
        Get-CloudPC | Format-Table Name, displayName, status
        .EXAMPLE
        Get-CloudPC -name "CloudPC01"
        .OUTPUTS
        PSCustomObject with Name (the managed device name, the Intune device name, that -Name expects;
        empty while the Cloud PC is provisioning and for Windows 365 Business Cloud PCs; use id then), id,
        managedDeviceName, managedDeviceId, displayName, userPrincipalName, status, provisioningPolicyName,
        imageDisplayName, lastModifiedDateTime, servicePlanType and servicePlanName.
        .NOTES
        Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
        API reference: https://learn.microsoft.com/graph/api/virtualendpoint-list-cloudpcs?view=graph-rest-beta
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [parameter(ParameterSetName = "Name")]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    Begin {
        Get-TokenValidity

        switch ($PsCmdlet.ParameterSetName) {
            Name {
                Write-Verbose "Name parameter provided"
                $filterName = [uri]::EscapeDataString($Name.Replace("'", "''"))
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/CloudPCs?`$filter=managedDeviceName+eq+'$filterName'"
            }
            default {
                Write-Verbose "No name parameter provided"
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/CloudPCs"
            }
        }
    }
    Process {
        write-verbose $url

        $Result = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET)

        if ($Result.Count -eq 0) {
            if ($PsCmdlet.ParameterSetName -eq "Name") {
                Write-Error "No Cloud PC found with managed device name '$Name'"
            }
            else {
                Write-Verbose "No Cloud PCs found in the tenant"
            }
            return
        }

        foreach ($CloudPC in $Result) {
            # Name is exactly what -Name expects (managedDeviceName); empty while there is none, never the displayName
            $cloudPcName = $CloudPC.managedDeviceName
            if ([string]::IsNullOrWhiteSpace($cloudPcName)) {
                $cloudPcName = $null
            }

            [PSCustomObject]@{
                Name                   = $cloudPcName
                id                     = $CloudPC.id
                managedDeviceName      = $CloudPC.managedDeviceName
                managedDeviceId        = $CloudPC.managedDeviceId
                displayName            = $CloudPC.displayName
                userPrincipalName      = $CloudPC.userPrincipalName
                status                 = $CloudPC.status
                provisioningPolicyName = $CloudPC.provisioningPolicyName
                imageDisplayName       = $CloudPC.imageDisplayName
                lastModifiedDateTime   = $CloudPC.lastModifiedDateTime
                servicePlanType        = $CloudPC.servicePlanType
                servicePlanName        = $CloudPC.servicePlanName
            }
        }
    }

}
