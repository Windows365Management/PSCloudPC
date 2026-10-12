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
    Exact display name of the Service Plan to assign the policy to (required if ProvisioningType is sharedByEntraGroup or sharedByUser, ignored for dedicated). The name must match exactly one Service Plan
    .PARAMETER AllotmentLicensesCount
    Number of licenses to allot for the Service Plan (default: 1)
    .EXAMPLE
    Set-CPCProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup"
    .EXAMPLE
    Set-CPCProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup" -Force (Removes existing assignments)
    .EXAMPLE
    Set-CPCProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup" -ProvisioningType "sharedByEntraGroup" -ServicePlanName "Cloud PC Frontline 2vCPU/8GB/128GB"
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/cloudpcprovisioningpolicy-assign?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcmanagementgroupassignmenttarget?view=graph-rest-beta
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
        [ValidateNotNullOrEmpty()]
        [string]$ServicePlanName,
        [parameter(Mandatory = $false)]
        [Int64]$AllotmentLicensesCount = 1

    )

    begin {
        Get-TokenValidity

        Get-AzureADGroupID -GroupName $GroupName

        If ($null -eq $script:GroupID) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No group found with name $GroupName" -Category ObjectNotFound
        }

        $Policy = Get-CPCProvisioningPolicy -name $Name

        If ($null -eq $Policy) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Provisioning Policy found with name $Name" -Category ObjectNotFound
            return
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($Policy.id)/assign"

        Write-Verbose "Assignment url: $($url)"

        If ($ProvisioningType -ne $Policy.provisioningType) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Provisioning Type mismatch. Policy Provisioning Type is $($Policy.provisioningType), provided Provisioning Type is $($ProvisioningType)"
        }

        If ($ProvisioningType -ne "dedicated") {
            # Shared provisioning types need exactly one servicePlanId; null is only valid for dedicated
            # https://learn.microsoft.com/graph/api/resources/cloudpcmanagementgroupassignmenttarget?view=graph-rest-beta
            If ([string]::IsNullOrWhiteSpace($ServicePlanName)) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "ServicePlanName is required when ProvisioningType is $($ProvisioningType)"
            }

            $ServicePlan = @(Get-CPCServicePlan -ServicePlanName $ServicePlanName)

            If ($ServicePlan.Count -eq 0) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Service Plan found with name $ServicePlanName" -Category ObjectNotFound
            }

            If ($ServicePlan.Count -gt 1) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($ServicePlan.Count) Service Plans found with name $ServicePlanName ($($ServicePlan.id -join ', ')). The name must match exactly one Service Plan"
            }

            $ServicePlanId = [string]$ServicePlan[0].id
            Write-Verbose "Resolved Service Plan $($ServicePlanName) to id $($ServicePlanId)"
        }
        ElseIf ($ServicePlanName) {
            Write-Warning "ServicePlanName is ignored for dedicated provisioning policies"
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
                        if ($_ -ne $script:GroupID) { $GroupID.Add($_) }
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
            Write-Verbose "Provisioning Type is $($ProvisioningType). Creating single assignment for GroupID $($script:GroupID) and ServicePlanName $($ServicePlanName) with $($ServicePlanId)"

            $params = @{
                Assignments = @(
                    @{
                        Target = @{
                            "@odata.type"          = "#microsoft.graph.cloudPcManagementGroupAssignmentTarget"
                            GroupId                = $script:GroupID
                            ServicePlanId          = $ServicePlanId
                            AllotmentDisplayName   = "FrontlineAssignment"
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
            Throw (Get-GraphErrorMessage $_)
        }

    }
}