function Set-CPCProvisioningPolicyAssignment {
    <#
    .SYNOPSIS
    Assign a Cloud PC Provisioning Policy to a group
    .DESCRIPTION
    Assign a Cloud PC Provisioning Policy to a group
    .PARAMETER Name
    Name of the Cloud PC Provisioning Policy
    .PARAMETER GroupName
    Name of the group to assign the policy to
    .PARAMETER Force
    If set, existing assignments will be removed and only the provided group will be assigned
    .PARAMETER ProvisioningType
    Provisioning Type of the Cloud PC Provisioning Policy. Valid values are: dedicated, sharedByUser, sharedByEntraGroup (Default: dedicated), if sharedByEntraGroup or sharedByUser is selected, only the provided group will be assigned, existing assignments will be removed
    .PARAMETER ServicePlanName
    Name of the Service Plan to assign the policy to (required if ProvisioningType is sharedByEntraGroup or sharedByUser)
    .PARAMETER AllotmentLicensesCount
    Number of licenses to allot for the Service Plan (default: 1)
    .EXAMPLE
    Set-CPCEnterpriseProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup"
    .EXAMPLE
    Set-CPCEnterpriseProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup" -Force (Removes existing assignments)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,
        [Parameter(mandatory = $false)]
        [string]$GroupName,
        [Parameter(mandatory = $false)]
        [switch]$Force,
        [ValidateSet('dedicated', 'sharedByUser', 'sharedByEntraGroup')]
        [string]$ProvisioningType = "dedicated",
        [parameter(Mandatory = $false)]
        [string]$ServicePlanName,
        [parameter(Mandatory = $false)]
        [Int64]$AllotmentLicensesCount = 1

    )

    begin {
        Get-TokenValidity

        Get-AzureADGroupID -GroupName $GroupName

        If ($null -eq $script:GroupID) {
            Throw "No group found with name $GroupName"
            return
        }

        $Policy = Get-CPCProvisioningPolicy -name $Name

        If ($null -eq $Policy) {
            Throw "No Provisioning Policy found with name $Name"
            return
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($Policy.id)/assign"

        Write-Verbose "Assignment url: $($url)"

        If ($ProvisioningType -ne $Policy.provisioningType) {
            Throw "Provisioning Type mismatch. Policy Provisioning Type is $($Policy.provisioningType), provided Provisioning Type is $($ProvisioningType)"
        }

        If ($ServicePlanName) {
            $ServicePlan = Get-CPCServicePlan -ServicePlanName $ServicePlanName

            If ($null -eq $ServicePlan) {
                Throw "No Service Plan found with name $ServicePlanName"
                return
            }
        }



    }

    Process {

        If ($ProvisioningType -eq "dedicated") {
            If ($Force) {
                Write-Verbose "Force parameter is set. Not adding existing assignments to body, using GroupID $($script:GroupID)"
                $GroupID = $script:GroupID
            }
            Else {

                Write-Verbose "Force parameter is not set. Adding existing, if present, assignments to body"

                $assignmenturl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($Policy.id)?`$expand=assignments"

                Write-Verbose "Current Assignments url: $($assignmenturl)"

                $assignments = Invoke-RestMethod -Uri $assignmenturl -Headers $script:Authheader -Method GET

                $currentassignments = $Assignments.assignments.target.GroupId

                Write-verbose "Current Assignments: $($currentassignments)"

                If ($null -eq $currentassignments) {
                    Write-Verbose "No assignments found"
                    $GroupID = $script:GroupID
                    Write-Verbose "GroupID Value: $($GroupID)"

                }
                Else {
                    Write-Verbose "Assignments found"
                    $GroupID = New-Object System.Collections.Generic.List[System.Object]
                    $GroupID.Add($script:GroupID)
                    $currentassignments | ForEach-Object {
                        $GroupID.Add($_)
                    }
                    Write-Verbose "GroupID Value: $($GroupID)"

                }

            }

            # Initialize the $params variable
            $params = @{
                Assignments = @()
            }

            # Iterate over the group IDs and add an element to the Assignments array for each group ID
            $GroupID | ForEach-Object {
                $params.Assignments += @{
                    Target = @{
                        GroupId = $_
                    }
                }
            }
        }
        else {
            Write-Verbose "Provisioning Type is $($ProvisioningType). Creating single assignment for GroupID $($script:GroupID) and ServicePlanName $($ServicePlanName) with $($ServicePlan.id)"

            $params = @{
                Assignments = @(
                    @{
                        Target = @{
                            "@odata.type"          = "#microsoft.graph.cloudPcManagementGroupAssignmentTarget"
                            GroupId                = $script:GroupID
                            ServicePlanId          = $ServicePlan.id
                            AllotmentDisplayName   = "FrontlineAssigment"
                            AllotmentLicensesCount = $AllotmentLicensesCount
                        }
                    }
                )
            }
        }

        $body = $params | ConvertTo-Json -Depth 100

        Write-Verbose "Request Body: $($body)"

        try {
            Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method Post -ContentType "application/json" -Body $body
        }
        catch {
            Throw $_.Exception.Message
        }

    }
}