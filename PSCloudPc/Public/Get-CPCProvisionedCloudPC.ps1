function Get-CPCProvisionedCloudPC {
    <#
    .SYNOPSIS
    Retrieves all provisioned Cloud PCs for a specific user group and service plan
    .DESCRIPTION
    The function retrieves all provisioned Cloud PCs that belong to a specific Microsoft Entra
    user group and use a specific Windows 365 service plan, using the Microsoft Graph beta API.

    This is useful for bulk management and reporting — for example, listing all Cloud PCs
    assigned to a particular department (Entra group) running a specific hardware tier
    (service plan), without having to filter the full Cloud PC list manually.

    Use Get-CPCServicePlan to find available service plan IDs.
    .PARAMETER GroupId
    The object ID (GUID) of the Microsoft Entra user group whose provisioned Cloud PCs to retrieve.
    .PARAMETER ServicePlanId
    The ID (GUID) of the Windows 365 service plan. Use Get-CPCServicePlan to find available plan IDs.
    .EXAMPLE
    Get-CPCProvisionedCloudPC -GroupId "30d0e128-de93-41dc-89ec-33d84bb662a0" -ServicePlanId "9ecf691d-8b82-46cb-b254-cd061b2c02fb"
    .EXAMPLE
    $plan = Get-CPCServicePlan | Where-Object { $_.displayName -like "*4vCPU*" } | Select-Object -First 1
    Get-CPCProvisionedCloudPC -GroupId "30d0e128-de93-41dc-89ec-33d84bb662a0" -ServicePlanId $plan.id
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    This function uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-getprovisionedcloudpcs
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServicePlanId
    )

    Begin {
        Get-TokenValidity

        # getProvisionedCloudPCs is a beta-only API
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/getProvisionedCloudPCs(groupId='$GroupId',servicePlanId='$ServicePlanId')"
        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Retrieving provisioned Cloud PCs for group '$GroupId' with service plan '$ServicePlanId'"

        try {
            $result = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method GET -ContentType "application/json"

            if ($null -eq $result -or $null -eq $result.value -or $result.value.Count -eq 0) {
                Write-Output "No provisioned Cloud PCs found for group '$GroupId' with service plan '$ServicePlanId'."
                return
            }

            $PSObjectResults = @()
            $result.value | ForEach-Object {
                $entry = [PSCustomObject]@{
                    id                     = $_.id
                    displayName            = $_.displayName
                    managedDeviceName      = $_.managedDeviceName
                    userPrincipalName      = $_.userPrincipalName
                    status                 = $_.status
                    servicePlanName        = $_.servicePlanName
                    servicePlanType        = $_.servicePlanType
                    provisioningPolicyName = $_.provisioningPolicyName
                    deviceRegionName       = $_.deviceRegionName
                    onPremisesConnectionName = $_.onPremisesConnectionName
                    diskEncryptionState    = $_.diskEncryptionState
                    provisioningType       = $_.provisioningType
                    lastModifiedDateTime   = $_.lastModifiedDateTime
                }
                $PSObjectResults += $entry
            }

            return $PSObjectResults
        }
        catch {
            Throw $_.Exception.Message
        }
    }
}
