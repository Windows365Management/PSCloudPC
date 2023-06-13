function Remove-CPCProvisioningPolicyAssignment {
    <#
    .SYNOPSIS
    Removes a Cloud PC Provisioning Policy Assignment
    .DESCRIPTION
    The function will remove a Cloud PC Provisioning Policy Assignment
    .PARAMETER name
    Enter the name of the Cloud PC Provisioning Policy
    .PARAMETER GroupName
    Enter the name of the Group to be removed from the Cloud PC Provisioning Policy
    .EXAMPLE
    Remove-CPCProvisioningPolicyAssignment -name "Provisioning Policy 01" -GroupName "Group 01"
#>

    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$Name,
        [parameter(mandatory = $true)][string]$GroupName
    )
    
    Begin {
        Get-TokenValidity

        $Assignments = Get-CPCProvisioningPolicyAssignment -Name $Name

        Get-AzureADGroupId -GroupName $GroupName

        Write-Verbose "Graph URL for Provisioning Policy: $Name"
        $AssigmentURL = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($Assignments.Policyid)/assignments/24aec8b0-c923-42f1-9ccf-da00b8bb98d7_057efbfe-a95d-4263-acb0-12b4a31fed8d"
    
        write-verbose "Assignment to delete URL: $AssigmentURL"
    }
    
    Process {
        

        try {
            Write-Verbose "Deleting Assignment $Groupname from Provisioning Policy $($Name)"
            Invoke-WebRequest -uri $AssigmentURL -Method DELETE -Headers $script:authHeader
        }
        catch {
            Throw $_.Exception.Message
        }
    }
}