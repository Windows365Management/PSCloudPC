function Set-CPCUserSettingsPolicyAssignment {
    <#
    .SYNOPSIS
    Assign a Cloud PC User Settings Policy to a group
    .DESCRIPTION
    Assign a Cloud PC User Settings Policy to a group
    .PARAMETER Name
    Name of the Cloud PC User Settings Policy 
    .PARAMETER GroupName
    Name of the group to assign the policy to
    .EXAMPLE
    Set-CPCUserSettingsPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup"
    .PARAMETER Force
    If set, existing assignments will be removed and only the provided group will be assigned
    .EXAMPLE
    Set-CPCUserSettingsPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup" -Force (Removes existing assignments)
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/cloudpcusersetting-assign?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,
        [Parameter(mandatory = $true)][ValidateNotNullOrEmpty()][string]$GroupName,
        [Parameter(mandatory = $false)][switch]$Force
    )
    
    begin {
        Get-TokenValidity

        try {
            $TargetGroupID = Get-AzureADGroupID -GroupName $GroupName
        }
        catch {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message $_.Exception.Message -Category InvalidOperation
        }

        If ([string]::IsNullOrWhiteSpace($TargetGroupID)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No group found with name $GroupName" -Category ObjectNotFound
        }

        $Policy = @(Get-CPCUserSettingsPolicy -name $Name)

        If ($Policy.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No User Settings Policy found with name $Name" -Category ObjectNotFound
        }

        If ($Policy.Count -gt 1) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($Policy.Count) User Settings Policies found with name $Name ($($Policy.id -join ', ')). The name must match exactly one policy."
        }

        $Policy = $Policy[0]

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings/$($Policy.id)/assign"

        Write-Verbose "Assignment url: $($url)"

    }

    Process {

        If ($Force) {
            Write-Verbose "Force parameter is set. Not adding existing assignments to body, using GroupID $($TargetGroupID)"
            $GroupID = $TargetGroupID
        }
        Else {

            Write-Verbose "Force parameter is not set. Adding existing, if present, assignments to body"

            $assignmenturl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings/$($Policy.id)?`$expand=assignments"
            
            Write-Verbose "Current Assignments url: $($assignmenturl)"

            $assignments = Invoke-RestMethod -Uri $assignmenturl -Headers $script:Authheader -Method GET

            $currentassignments = $Assignments.assignments.target.GroupId

            Write-verbose "Current Assignments: $($currentassignments)"

            If ($null -eq $currentassignments) {
                Write-Verbose "No assignments found"
                $GroupID = $TargetGroupID
                Write-Verbose "GroupID Value: $($GroupID)"

            }
            Else {
                Write-Verbose "Assignments found"
                $GroupID = New-Object System.Collections.Generic.List[System.Object]
                $GroupID.Add($TargetGroupID)
                $currentassignments | ForEach-Object {
                    if ($_ -ne $TargetGroupID) { $GroupID.Add($_) }
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

        $body = $params | ConvertTo-Json -Depth 100

        Write-Verbose "Request Body: $($body)"

        if ($PSCmdlet.ShouldProcess($Policy.displayName, "Assign User Settings Policy to group '$GroupName'")) {
            try {
                # Graph returns 204 No Content
                $null = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method Post -ContentType "application/json" -Body $body
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
        
    }
}