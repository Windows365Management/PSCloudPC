function Get-CPCFrontlineAccessState {
    <#
    .SYNOPSIS
    Retrieves the frontline access state of a Frontline Cloud PC
    .DESCRIPTION
    Returns the current access state for a Windows 365 Frontline Cloud PC using the
    Microsoft Graph beta getFrontlineCloudPcAccessState API.

    Frontline Cloud PCs are shared-use devices backed by a pool licence. The access
    state indicates whether the device is currently active, activating, in standby,
    unassigned, or unavailable due to licence constraints. This is useful for
    monitoring shared-licence availability and diagnosing activation failures before
    escalating to a full reprovision.

    Returns 400 Bad Request when called against a dedicated (non-Frontline) Cloud PC.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId.
    .PARAMETER Name
    The managed device name of the Frontline Cloud PC. Use Get-CloudPC to find names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Frontline Cloud PC. Use Get-CloudPC to find IDs.
    Mutually exclusive with -Name.
    .EXAMPLE
    Get-CPCFrontlineAccessState -Name "CPC-User-XXXX"
    .EXAMPLE
    Get-CPCFrontlineAccessState -CloudPCId "b0a9cde2-e170-4dd9-97c3-ad1d3328a711"
    .EXAMPLE
    # Check all Cloud PCs and show only Frontline devices currently in standby
    Get-CloudPC | Where-Object { $_.servicePlanType -eq 'frontline' } |
        ForEach-Object { Get-CPCFrontlineAccessState -CloudPCId $_.id } |
        Where-Object { $_.accessState -eq 'standbyMode' }
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    Only valid for Frontline (shared-licence) Cloud PCs; dedicated Cloud PCs return HTTP 400.
    This function uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-getfrontlinecloudpcaccessstate?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    Begin {
        Get-TokenValidity

        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $CloudPC = Get-CloudPC -Name $Name

            if ($null -eq $CloudPC -or @($CloudPC).Count -eq 0) {
                Throw "No Cloud PC found with name '$Name'. Use Get-CloudPC to verify the managed device name."
            }

            # Take the first result in case the filter returns multiple
            $CloudPC = @($CloudPC)[0]
            $targetId   = $CloudPC.id
            $targetName = $CloudPC.displayName
        }
        else {
            $targetId   = $CloudPCId
            $targetName = $CloudPCId
        }

        # getFrontlineCloudPcAccessState is a beta-only API; admin path via virtualEndpoint
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$targetId/getFrontlineCloudPcAccessState"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Retrieving frontline access state for Cloud PC '$targetName' (id: $targetId)"

        try {
            $result = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method GET -ContentType "application/json"

            [PSCustomObject]@{
                CloudPCName = $targetName
                CloudPCId   = $targetId
                accessState = $result.value
            }
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            if ($statusCode -eq 400) {
                Throw "Cloud PC '$targetName' is not a Frontline Cloud PC. getFrontlineCloudPcAccessState only applies to shared-licence Frontline devices."
            }
            Throw $_.Exception.Message
        }
    }
}
