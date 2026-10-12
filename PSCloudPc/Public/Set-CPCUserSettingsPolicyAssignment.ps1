function Set-CPCUserSettingsPolicyAssignment {
    <#
    .SYNOPSIS
    Assign a Cloud PC User Settings Policy to a group
    .DESCRIPTION
    Assign a Cloud PC User Settings Policy to a group. The assign action replaces all assignments of the policy, so the existing groups are sent again together with the new group (each group once). Use -Force to replace the existing groups with only the new group.
    When existing group assignments will be removed (-Force while other groups are assigned), the command asks for confirmation (ConfirmImpact High) and names the groups that lose the assignment. Use -Confirm:$false to skip the prompt in scripts.
    .PARAMETER Name
    Exact name of the Cloud PC User Settings Policy. The name must match exactly one policy
    .PARAMETER GroupName
    Exact display name of the group to assign the policy to. The name must match exactly one group
    .PARAMETER Force
    If set, existing assignments will be removed and only the provided group will be assigned
    .EXAMPLE
    Set-CPCUserSettingsPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup"
    .EXAMPLE
    Set-CPCUserSettingsPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup" -Force (Removes existing assignments)
    .NOTES
    Required permission: CloudPC.ReadWrite.All, plus Group.ReadBasic.All to look up the group by name
    https://learn.microsoft.com/graph/api/cloudpcusersetting-assign?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/cloudpcusersetting-get?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcmanagementgroupassignmenttarget?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/group-list?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess)]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,
        [Parameter(mandatory = $false)][string]$GroupName,
        [Parameter(mandatory = $false)][switch]$Force

    )

    begin {
        Get-TokenValidity

        If ([string]::IsNullOrWhiteSpace($GroupName)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "GroupName is required"
        }

        # Stops the command when 0 or more than 1 group has this exact name
        $GroupId = Get-AzureADGroupID -GroupName $GroupName -Cmdlet $PSCmdlet
        Write-Verbose "Resolved group $($GroupName) to id $($GroupId)"

        # Check the name again on the client: the server-side filter of Get-CPCUserSettingsPolicy may match another policy
        # for names with special characters, and assign replaces all assignments of the policy it is sent to
        $Policy = @(Get-CPCUserSettingsPolicy -name $Name | Where-Object { $_.displayName -eq $Name })

        If ($Policy.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No User Settings Policy found with name $Name" -Category ObjectNotFound
        }

        If ($Policy.Count -gt 1) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($Policy.Count) User Settings Policies found with name $Name ($($Policy.id -join ', ')). The name must match exactly one User Settings Policy"
        }

        $PolicyId = [string]$Policy[0].id

        If ([string]::IsNullOrWhiteSpace($PolicyId)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "User Settings Policy $Name has no id" -Category InvalidResult
        }

        $assignmenturl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings/$($PolicyId)?`$expand=assignments"

        Write-Verbose "Current Assignments url: $($assignmenturl)"

        try {
            $PolicyDetail = Invoke-APIRequest -uri $assignmenturl -Token $script:Authtoken -Method GET -ErrorAction Stop
        }
        catch {
            # Without the current assignments the assign request could remove them
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message (Get-GraphErrorMessage $_) -Category InvalidOperation
        }

        # A missing assignments property is not the same as no assignments: don't guess, the assign request replaces them all
        If ($null -eq $PolicyDetail -or $PolicyDetail.PSObject.Properties.Name -notcontains "assignments") {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Graph returned User Settings Policy $Name without its assignments, so the current assignments can't be kept. No assignment was sent" -Category InvalidResult
        }

        $CurrentGroupIds = [System.Collections.Generic.List[string]]::new()
        $CurrentSeenGroupIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($currentGroupId in @($PolicyDetail.assignments.target.groupId)) {
            If (-not [string]::IsNullOrWhiteSpace($currentGroupId) -and $CurrentSeenGroupIds.Add([string]$currentGroupId)) {
                $CurrentGroupIds.Add([string]$currentGroupId)
            }
        }

        Write-Verbose "Current Assignments: $($CurrentGroupIds -join ', ')"

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings/$($PolicyId)/assign"

        Write-Verbose "Assignment url: $($url)"

    }

    Process {

        # assign replaces every assignment of the policy, and Graph rejects a body with the same group twice (400),
        # so send each group id once (group ids are GUIDs, compare case-insensitive)
        $GroupIds = [System.Collections.Generic.List[string]]::new()
        $SeenGroupIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        If ($Force) {
            Write-Verbose "Force parameter is set. Existing assignments are replaced by group $($GroupId)"
        }
        Else {
            Write-Verbose "Force parameter is not set. Keeping existing assignments"
            foreach ($currentGroupId in $CurrentGroupIds) {
                If ($SeenGroupIds.Add($currentGroupId)) {
                    $GroupIds.Add($currentGroupId)
                }
            }
        }

        If ($SeenGroupIds.Add($GroupId)) {
            $GroupIds.Add($GroupId)
        }
        Else {
            Write-Verbose "Group $($GroupName) ($($GroupId)) is already assigned"
        }

        $DroppedGroupIds = @($CurrentGroupIds | Where-Object { -not $SeenGroupIds.Contains($_) })

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

        $body = $params | ConvertTo-Json -Depth 10

        Write-Verbose "Request: POST $($url)"
        Write-Verbose "Request Body: $($body)"

        $Target = "User Settings Policy $($Name) ($($PolicyId))"

        If ($DroppedGroupIds.Count -gt 0) {
            # Removing assignments takes the settings away from those groups, so confirm with ConfirmImpact High
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
