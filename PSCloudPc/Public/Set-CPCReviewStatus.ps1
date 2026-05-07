function Set-CPCReviewStatus {
    <#
    .SYNOPSIS
    Sets the review status of a Cloud PC to flag it as suspicious or clear it
    .DESCRIPTION
    The function sets the review status of a specific Cloud PC using the Microsoft
    Graph beta API. Use this to mark a Cloud PC as "in review" when you suspect
    it has been compromised or is involved in a security incident. When a Cloud PC
    is placed in review, you can optionally restrict end-user access and capture a
    snapshot to an Azure Storage account for forensic analysis.

    Once the investigation is complete, use this function again with -InReview:$false
    to return the Cloud PC to a normal state and restore full user access.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name.
    .PARAMETER InReview
    Set to $true to place the Cloud PC in review (suspicious). Set to $false to
    clear the review and return to normal state. Default: $true.
    .PARAMETER UserAccessLevel
    The access level to apply to the end user while the Cloud PC is in review.
    Valid values: 'unrestricted' (user retains full access), 'restricted' (user
    access is limited). Default: 'restricted'.
    Only applicable when -InReview is $true.
    .PARAMETER AzureStorageAccountId
    Optional. The resource ID of the Azure Storage account where the Cloud PC
    snapshot will be saved for forensic analysis. Use the full ARM resource ID:
    /subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}
    .EXAMPLE
    Set-CPCReviewStatus -Name "CPC-User-XXXX"
    Places the Cloud PC in review with restricted user access (default behaviour).
    .EXAMPLE
    Set-CPCReviewStatus -CloudPCId "4b5ad5e0-6a0b-4ffc-818d-36bb23cf4dbd" -InReview $true -UserAccessLevel restricted
    .EXAMPLE
    Set-CPCReviewStatus -Name "CPC-User-XXXX" -InReview $false
    Clears the review status and returns the Cloud PC to normal operation.
    .EXAMPLE
    Set-CPCReviewStatus -Name "CPC-User-XXXX" -InReview $true -UserAccessLevel restricted `
        -AzureStorageAccountId "/subscriptions/f68bd846-16ad-4b51-a7c6-c84944a3367c/resourceGroups/ForensicRG/providers/Microsoft.Storage/storageAccounts/forensicstorage"
    .EXAMPLE
    Set-CPCReviewStatus -Name "CPC-User-XXXX" -WhatIf
    .NOTES
    Requires CloudPC.ReadWrite.All permission (delegated or application).
    This function uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-setreviewstatus
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId,

        [Parameter(Mandatory = $false)]
        [bool]$InReview = $true,

        [Parameter(Mandatory = $false)]
        [ValidateSet('unrestricted', 'restricted')]
        [string]$UserAccessLevel = 'restricted',

        [Parameter(Mandatory = $false)]
        [string]$AzureStorageAccountId
    )

    begin {
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

        # setReviewStatus is a beta-only POST action on the Cloud PC resource
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$targetId/setReviewStatus"

        Write-Verbose "URL: $url"
    }

    Process {
        # Build the reviewStatus body
        $reviewStatus = @{
            inReview        = $InReview
            userAccessLevel = $UserAccessLevel
        }

        if ($PSBoundParameters.ContainsKey('AzureStorageAccountId') -and -not [string]::IsNullOrWhiteSpace($AzureStorageAccountId)) {
            $reviewStatus['azureStorageAccountId'] = $AzureStorageAccountId
        }

        $body = @{ reviewStatus = $reviewStatus } | ConvertTo-Json -Depth 10

        $action = if ($InReview) { "Mark as in-review (userAccessLevel=$UserAccessLevel)" } else { "Clear review status" }
        Write-Verbose "Setting review status on Cloud PC '$targetName' (id: $targetId): InReview=$InReview, UserAccessLevel=$UserAccessLevel"

        if ($PSCmdlet.ShouldProcess($targetName, $action)) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -Body $body -ContentType "application/json"
                if ($InReview) {
                    Write-Output "Cloud PC '$targetName' has been placed in review with access level '$UserAccessLevel'."
                }
                else {
                    Write-Output "Cloud PC '$targetName' review status cleared. Device returned to normal state."
                }
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
