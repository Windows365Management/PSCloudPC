function Get-CPCReviewStatus {
    <#
    .SYNOPSIS
    Retrieves the review status of a Cloud PC
    .DESCRIPTION
    The function retrieves the current review status of a specific Cloud PC using the
    Microsoft Graph beta API. Use this to check whether a Cloud PC has been marked
    "in review" by an administrator (for example, when the device is suspected of
    being compromised or involved in a security incident).

    The review status includes whether the device is in review, the access level
    applied to the end user, the time the review started, and details about any
    linked Azure Storage snapshot.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name.
    .EXAMPLE
    Get-CPCReviewStatus -Name "CPC-User-XXXX"
    .EXAMPLE
    Get-CPCReviewStatus -CloudPCId "4b5ad5e0-6a0b-4ffc-818d-36bb23cf4dbd"
    .EXAMPLE
    # Check review status for all Cloud PCs and show those that are in review
    Get-CloudPC | ForEach-Object { Get-CPCReviewStatus -CloudPCId $_.id } |
        Where-Object { $_.inReview -eq $true }
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    This function uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-retrievereviewstatus
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

        # retrieveReviewStatus is a beta-only GET action on the Cloud PC resource
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$targetId/retrieveReviewStatus"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Retrieving review status for Cloud PC '$targetName' (id: $targetId)"

        try {
            $result = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method GET -ContentType "application/json"
        }
        catch {
            Throw $_.Exception.Message
        }

        if ($null -eq $result) {
            Write-Output "No review status returned for Cloud PC '$targetName'."
            return
        }

        [PSCustomObject]@{
            CloudPCName                = $targetName
            CloudPCId                  = $targetId
            inReview                   = $result.inReview
            userAccessLevel            = $result.userAccessLevel
            reviewStartDateTime        = $result.reviewStartDateTime
            restorePointDateTime       = $result.restorePointDateTime
            subscriptionId             = $result.subscriptionId
            subscriptionName           = $result.subscriptionName
            azureStorageAccountId      = $result.azureStorageAccountId
            azureStorageAccountName    = $result.azureStorageAccountName
            azureStorageContainerName  = $result.azureStorageContainerName
        }
    }
}
