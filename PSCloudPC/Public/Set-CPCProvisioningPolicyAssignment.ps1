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
    .EXAMPLE
    Set-CPCProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup"
    .EXAMPLE
    Set-CPCProvisioningPolicyAssignment -Name "MyUserSettingsPolicy" -GroupName "MyGroup" -Force (Removes existing assignments)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,
        [Parameter(mandatory = $false)][string]$GroupName,
        [Parameter(mandatory = $false)][switch]$Force
        # TODO: Add SupportsShouldProcess
        # TODO: Add Frontline Support

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

    }

    Process {

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
                # $GroupID = $currentassignments += $script:GroupID
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

        $body = $params | ConvertTo-Json -Depth 100

        try {
            Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method Post -ContentType "application/json" -Body $body
        }
        catch {
            Throw $_.Exception.Message
        }
        
    }
}