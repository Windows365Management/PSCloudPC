function Remove-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Removes a Cloud PC Provisioning Policy
    .DESCRIPTION
    The function will remove a Cloud PC Provisioning Policy.
    The name must match the display name of exactly one policy (exact match, not case sensitive).
    If no policy or more than one policy has that name, nothing is removed and the command stops.
    You can't delete a policy that's in use.
    The function asks for confirmation before it removes the policy. In a non-interactive session
    (pwsh -File, a pipeline or a scheduled task) the confirmation prompt fails and nothing is removed,
    so pass -Confirm:$false there.
    .PARAMETER name
    Enter the name of the Cloud PC Provisioning Policy
    .EXAMPLE
    Remove-CPCProvisioningPolicy -name "Provisioning Policy 01"
    .EXAMPLE
    Remove-CPCProvisioningPolicy -name "Provisioning Policy 01" -WhatIf
    .EXAMPLE
    Remove-CPCProvisioningPolicy -name "Provisioning Policy 01" -Confirm:$false

    Removes the policy without asking for confirmation, as needed in scripts and pipelines.
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/cloudpcprovisioningpolicy-delete?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/virtualendpoint-list-provisioningpolicies?view=graph-rest-beta
#>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param (
        [parameter(mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name
    )

    Begin {
        Get-TokenValidity

        #Graph's displayName eq filter is case-sensitive, so list all policies and match the name on the client
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies?`$select=id,displayName"
        Write-Verbose "Looking up Provisioning Policy '$Name': GET $url"

        try {
            $result = Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET -ErrorAction Stop
        }
        catch {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message (Get-GraphErrorMessage $_) -Category InvalidOperation
        }

        #Exact match, not case sensitive; a partial name never matches
        $Policy = @($result | Where-Object { $_.displayName -eq $Name })

        if ($Policy.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Provisioning Policy found with name '$Name'. Nothing was removed." -Category ObjectNotFound
        }

        if ($Policy.Count -gt 1) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($Policy.Count) Provisioning Policies found with name '$Name' ($($Policy.id -join ', ')). Nothing was removed."
        }

        $PolicyId = $Policy[0].id
        $ParsedId = [guid]::Empty
        if ($PolicyId -isnot [string] -or -not [guid]::TryParseExact($PolicyId, "D", [ref]$ParsedId)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The Provisioning Policy '$Name' has no valid id ('$PolicyId'). Nothing was removed." -Category InvalidData
        }

        $deleteurl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$PolicyId"
    }

    Process {
        if ($PSCmdlet.ShouldProcess("$($Policy[0].displayName) ($PolicyId)", "Remove Provisioning Policy")) {
            Write-Verbose "Removing Provisioning Policy: DELETE $deleteurl"
            try {
                Invoke-RestMethod -Uri $deleteurl -Method DELETE -Headers $script:Authheader -ErrorAction Stop
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }

}
