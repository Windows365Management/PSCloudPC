Function Get-CPCProvisioningPolicyAssignment {
    <#
    .SYNOPSIS
    Get Cloud PC Provisioning Policy Assignments
    .DESCRIPTION
    This function return all assignments for a Cloud PC Provisioning Policy
    .PARAMETER Name
    Name of the Cloud PC Provisioning Policy
    .EXAMPLE
    Get-CPCProvisioningPolicyAssignment -Name "MyProvisioningPolicy"
    #>

    [CmdletBinding()]
    param (
        [parameter(mandatory, ParameterSetName = "Name")]
        [string]$Name 
    )

    Begin {
        Get-TokenValidity

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies?`$filter=displayName+eq+'$($Name)'"

        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader

        if ($null -eq $result) {
            Write-Error "No Provisioning Policy's returned"
            break
        }

        $Convert = $result.content | ConvertFrom-Json

        $assignmenturl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($Convert.value.id)?`$expand=assignments"

        Write-Verbose "Asssingment URL: $assignmenturl"


    }
    Process {
        $Assignments = Invoke-WebRequest -uri $assignmenturl -Method GET -Headers $script:authHeader
    
        if ($null -eq $Assignments) {
            Write-Error "No Assignments for Provisioning Policy $($Name) returned"
            break
        }

        $Convert = $Assignments | ConvertFrom-Json

        Write-Verbose "Convert: $Convert"

        Write-Verbose "Assignments: $($Convert.assignments)"

        $GroupNames = New-Object System.Collections.Generic.List[System.Object]

        foreach ($assignment in $Convert.assignments) {
            Get-AzureADGroupName -id $assignment.target.groupId
            $GroupNames.Add($script:GroupName)
        }

        If ($Null -ne $Convert.assignments.target.ServicePlanId) {
            $Serviceplannames = New-Object System.Collections.Generic.List[System.Object]

            foreach ($serviceplan in $Convert.assignments.target.ServicePlanId) {
                Get-CPCServicePlanname -ServicePlanId $serviceplan
                $Serviceplannames.Add($script:ServicePlanName)
            }
        }
    
        $Info = [PSCustomObject]@{
            Policyid        = $Convert.id
            displayName     = $Convert.displayName
            assignments     = $GroupNames
            assignmentsid   = $Convert.assignments.target.groupId
            serviceplanName = $Serviceplannames
        }
        $Info  
    }
}