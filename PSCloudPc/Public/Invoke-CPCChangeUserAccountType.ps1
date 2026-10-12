function Invoke-CPCChangeUserAccountType {
    <#
    .SYNOPSIS
    Changes the local account type of the user on a Cloud PC
    .DESCRIPTION
    The function will change the user account type on a specific Cloud PC between
    standard user and local administrator using the Microsoft Graph beta API.
    Use this to elevate a user to local admin for troubleshooting or to demote
    an administrator back to a standard user for compliance reasons.

    Microsoft supports changing the account type only for Cloud PCs with a Windows 365
    Business license, not for Windows 365 Enterprise. For other Cloud PCs Graph returns
    400 badRequest; when the Cloud PC's productType shows it isn't a Business Cloud PC,
    the error says so.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId. The name must match
    exactly one Cloud PC; otherwise no request is sent. Windows 365 Business Cloud PCs
    and Cloud PCs that are still provisioning have no managed device name, so use
    -CloudPCId (or pipe them from Get-CloudPC) for them.

    A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
    non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
    with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
    -ErrorVariable and $Error can also hold the underlying Graph errors. The command
    returns no output when the request is accepted.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name. Accepts pipeline input by property name (id or
    CloudPCId), for example from Get-CloudPC; -UserAccountType applies to every piped Cloud PC.
    .PARAMETER UserAccountType
    The account type to set for the user on the Cloud PC.
    Valid values: 'standardUser', 'administrator'.
    .EXAMPLE
    Invoke-CPCChangeUserAccountType -Name "CPC-User-XXXX" -UserAccountType administrator
    .EXAMPLE
    Invoke-CPCChangeUserAccountType -CloudPCId "00000000-0000-0000-0000-000000000000" -UserAccountType standardUser
    # Pipeline: Get-CloudPC -Name "CPC-User-XXXX" | Invoke-CPCChangeUserAccountType -UserAccountType standardUser
    .EXAMPLE
    Invoke-CPCChangeUserAccountType -Name "CPC-User-XXXX" -UserAccountType administrator -WhatIf
    .NOTES
    Windows 365 Business Cloud PCs only (productType business); Enterprise Cloud PCs get 400 badRequest.
    https://learn.microsoft.com/microsoft-365/lighthouse/m365-lighthouse-change-cloud-pc-account-type
    Required permission: CloudPC.ReadWrite.All (delegated or application).
    This action uses the Microsoft Graph beta endpoint:
    POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/changeUserAccountType
    https://learn.microsoft.com/graph/api/cloudpc-changeuseraccounttype?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('standardUser', 'administrator')]
        [string]$UserAccountType
    )

    begin {
        Get-TokenValidity

        # ValidateSet ignores case, so send the documented cloudPcUserAccountType value
        $accountType = (@("standardUser", "administrator") -eq $UserAccountType)[0]

        $body = @{
            userAccountType = $accountType
        } | ConvertTo-Json -Depth 10
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -Name $Name
        }
        else {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -CloudPCId $CloudPCId
        }

        # The lookup wrote an error for this Cloud PC; continue with the next pipeline object
        if ($null -eq $CloudPC) {
            return
        }

        $targetName = Get-CPCCloudPCLabel -CloudPC $CloudPC
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/changeUserAccountType"

        if ($PSCmdlet.ShouldProcess($targetName, "Change user account type to '$accountType'")) {
            Write-Verbose "Request: POST $url"
            try {
                $null = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -Body $body -ContentType "application/json" -ErrorAction Stop
                Write-Verbose "User account type change to '$accountType' requested for Cloud PC $targetName"
            }
            catch {
                # Graph answers 400 badRequest for Cloud PCs that aren't Windows 365 Business; say so when the product type shows it
                $hint = $null
                $statusCode = $null
                if ($null -ne $_.Exception.Response) {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }
                $isBadRequest = ($statusCode -eq 400) -or ((Get-GraphErrorMessage $_) -match "badRequest|400 \(Bad Request\)")

                $productType = [string]$CloudPC.productType
                if ([string]::IsNullOrWhiteSpace($productType)) {
                    $productType = [string]$CloudPC.servicePlanType
                }

                if ($isBadRequest -and -not [string]::IsNullOrWhiteSpace($productType) -and $productType -ne "business") {
                    $hint = "Changing the account type is only supported for Windows 365 Business Cloud PCs; this Cloud PC's product type is '$productType'."
                }

                Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Change user account type" -CloudPC $CloudPC -Hint $hint
                return
            }
        }
    }
}
