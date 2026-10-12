function Set-CPCProvisioningPolicyAssignment {
    <#
    .SYNOPSIS
    Assign a Cloud PC Provisioning Policy to a group
    .DESCRIPTION
    Assign a Cloud PC Provisioning Policy to a group. The assign action replaces all assignments of the policy, so for a dedicated policy the existing groups are sent again together with the new group (each group once). Use -Force to replace the existing groups with only the new group.
    When existing group assignments will be removed (with -Force, or for a shared provisioning type that already has another group), the command asks for confirmation (ConfirmImpact High) and names the groups that lose the assignment. Removing an assignment puts the Cloud PCs of that group into their grace period; Windows 365 Frontline Cloud PCs in shared mode are deleted without a grace period. Use -Confirm:$false to skip the prompt in scripts.
    .PARAMETER Name
    Exact name of the Cloud PC Provisioning Policy. The name must match exactly one policy
    .PARAMETER GroupName
    Exact display name of the group to assign the policy to. The name must match exactly one group
    .PARAMETER Force
    If set, existing assignments will be removed and only the provided group will be assigned
    .PARAMETER ProvisioningType
    Provisioning Type of the Cloud PC Provisioning Policy. Valid values are: dedicated, sharedByUser, sharedByEntraGroup (Default: dedicated), if sharedByEntraGroup or sharedByUser is selected, only the provided group will be assigned, existing assignments will be removed
    .PARAMETER ServicePlanName
    Exact display name of the Service Plan to assign the policy to (required if ProvisioningType is sharedByEntraGroup or sharedByUser, ignored for dedicated). The name must match exactly one Service Plan
    .PARAMETER AllotmentLicensesCount
    Not sent to Graph anymore: the assignment target (cloudPcManagementGroupAssignmentTarget) documents only groupId and servicePlanId. Kept so existing scripts keep working
    .EXAMPLE
    Set-CPCProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup"
    .EXAMPLE
    Set-CPCProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup" -Force (Removes existing assignments)
    .EXAMPLE
    Set-CPCProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup" -ProvisioningType "sharedByEntraGroup" -ServicePlanName "Cloud PC Frontline 2vCPU/8GB/128GB"
    .NOTES
    Required permission: CloudPC.ReadWrite.All, plus Group.ReadBasic.All to look up the group by name
    https://learn.microsoft.com/graph/api/cloudpcprovisioningpolicy-assign?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/cloudpcprovisioningpolicy-get?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta (provisioningType is an evolvable enum: sharedByUser and sharedByEntraGroup need the Prefer: include-unknown-enum-members header)
    https://learn.microsoft.com/graph/api/resources/cloudpcmanagementgroupassignmenttarget?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/group-list?view=graph-rest-beta
    https://learn.microsoft.com/windows-365/enterprise/provisioning (removing an assignment and the grace period)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess)]
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

        If ([string]::IsNullOrWhiteSpace($GroupName)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "GroupName is required"
        }

        # Stops the command when 0 or more than 1 group has this exact name
        $GroupId = Get-AzureADGroupID -GroupName $GroupName -Cmdlet $PSCmdlet
        Write-Verbose "Resolved group $($GroupName) to id $($GroupId)"

        # Check the name again on the client: the server-side filter of Get-CPCProvisioningPolicy may match another policy
        # for names with special characters, and assign replaces all assignments of the policy it is sent to
        $Policy = @(Get-CPCProvisioningPolicy -name $Name | Where-Object { $_.displayName -eq $Name })

        If ($Policy.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Provisioning Policy found with name $Name" -Category ObjectNotFound
        }

        If ($Policy.Count -gt 1) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($Policy.Count) Provisioning Policies found with name $Name ($($Policy.id -join ', ')). The name must match exactly one Provisioning Policy"
        }

        $PolicyId = [string]$Policy[0].id

        If ([string]::IsNullOrWhiteSpace($PolicyId)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Provisioning Policy $Name has no id" -Category InvalidResult
        }

        # Read the policy with its assignments. provisioningType is an evolvable enum: without this Prefer header
        # sharedByUser and sharedByEntraGroup come back as unknownFutureValue
        $assignmenturl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($PolicyId)?`$expand=assignments"

        Write-Verbose "Current Assignments url: $($assignmenturl)"

        try {
            $PolicyDetail = Invoke-APIRequest -uri $assignmenturl -Token $script:Authtoken -Method GET -AdditionalHeaders @{ Prefer = "include-unknown-enum-members" } -ErrorAction Stop
        }
        catch {
            # Without the current assignments the assign request could remove them
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message (Get-GraphErrorMessage $_) -Category InvalidOperation
        }

        # A missing assignments property is not the same as no assignments: don't guess, the assign request replaces them all
        If ($null -eq $PolicyDetail -or $PolicyDetail.PSObject.Properties.Name -notcontains "assignments") {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Graph returned Provisioning Policy $Name without its assignments, so the current assignments can't be kept. No assignment was sent" -Category InvalidResult
        }

        $CurrentGroupIds = [System.Collections.Generic.List[string]]::new()
        $CurrentSeenGroupIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($currentGroupId in @($PolicyDetail.assignments.target.groupId)) {
            If (-not [string]::IsNullOrWhiteSpace($currentGroupId) -and $CurrentSeenGroupIds.Add([string]$currentGroupId)) {
                $CurrentGroupIds.Add([string]$currentGroupId)
            }
        }

        Write-Verbose "Current Assignments: $($CurrentGroupIds -join ', ')"

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($PolicyId)/assign"

        Write-Verbose "Assignment url: $($url)"

        If ($ProvisioningType -ne $PolicyDetail.provisioningType) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Provisioning Type mismatch. Policy Provisioning Type is $($PolicyDetail.provisioningType), provided Provisioning Type is $($ProvisioningType)"
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

        If ($PSBoundParameters.ContainsKey("AllotmentLicensesCount")) {
            Write-Warning "AllotmentLicensesCount ($($AllotmentLicensesCount)) is not sent: the assignment target only documents groupId and servicePlanId"
        }

    }

    Process {

        # assign replaces every assignment of the policy, and Graph rejects a body with the same group twice (400),
        # so send each group id once (group ids are GUIDs, compare case-insensitive)
        $GroupIds = [System.Collections.Generic.List[string]]::new()
        $SeenGroupIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        If ($ProvisioningType -eq "dedicated" -and -not $Force) {
            Write-Verbose "Force parameter is not set. Keeping existing assignments"
            foreach ($currentGroupId in $CurrentGroupIds) {
                If ($SeenGroupIds.Add($currentGroupId)) {
                    $GroupIds.Add($currentGroupId)
                }
            }
        }
        Else {
            Write-Verbose "Force is set or the Provisioning Type is $($ProvisioningType). Existing assignments are replaced by group $($GroupId)"
        }

        If ($SeenGroupIds.Add($GroupId)) {
            $GroupIds.Add($GroupId)
        }
        Else {
            Write-Verbose "Group $($GroupName) ($($GroupId)) is already assigned"
        }

        $DroppedGroupIds = @($CurrentGroupIds | Where-Object { -not $SeenGroupIds.Contains($_) })

        If ($ProvisioningType -eq "dedicated") {
            $params = @{
                assignments = @(
                    foreach ($AssignGroupId in $GroupIds) {
                        @{
                            target = @{
                                "@odata.type" = "#microsoft.graph.cloudPcManagementGroupAssignmentTarget"
                                groupId       = $AssignGroupId
                            }
                        }
                    }
                )
            }
        }
        Else {
            Write-Verbose "Provisioning Type is $($ProvisioningType). Creating single assignment for GroupID $($GroupId) and ServicePlanName $($ServicePlanName) with $($ServicePlanId)"

            $params = @{
                assignments = @(
                    @{
                        target = @{
                            "@odata.type" = "#microsoft.graph.cloudPcManagementGroupAssignmentTarget"
                            groupId       = $GroupId
                            servicePlanId = $ServicePlanId
                        }
                    }
                )
            }
        }

        $body = $params | ConvertTo-Json -Depth 10

        Write-Verbose "Request: POST $($url)"
        Write-Verbose "Request Body: $($body)"

        $Target = "Provisioning Policy $($Name) ($($PolicyId))"

        If ($DroppedGroupIds.Count -gt 0) {
            # Removing assignments puts Cloud PCs into their grace period (Frontline shared: deleted without one), so confirm with ConfirmImpact High
            $Action = "Assign group(s) $($GroupIds -join ', ') and REMOVE the assignment of group(s) $($DroppedGroupIds -join ', ')"
            Write-Warning "The assignment of group(s) $($DroppedGroupIds -join ', ') will be removed from $($Target)"

            $ConfirmParams = @{ Target = $Target; Action = $Action; WhatIf = [bool]$WhatIfPreference }
            If ($PSBoundParameters.ContainsKey("Confirm")) {
                $ConfirmParams.Confirm = [bool]$PSBoundParameters["Confirm"]
            }
            $Approved = Confirm-CPCHighImpactAction @ConfirmParams
        }
        Else {
            $Approved = $PSCmdlet.ShouldProcess($Target, "Assign group(s) $($GroupIds -join ', ')")
        }

        If ($Approved) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method Post -ContentType "application/json" -Body $body -ErrorAction Stop
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }

    }
}
