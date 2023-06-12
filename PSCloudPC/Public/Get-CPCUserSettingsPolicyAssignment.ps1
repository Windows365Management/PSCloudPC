Function Get-CPCUserSettingsPolicyAssignment {
    <#
    .SYNOPSIS
    Get Cloud PC User Settings Policy Assignments
    .DESCRIPTION
    This function return all assignments for a Cloud PC User Settings Policy
    .PARAMETER Name
    Name of the Cloud PC User Settings Policy
    .EXAMPLE
    Get-CPCUserSettingsPolicyAssignment -Name "MyUserSettingsPolicy"
    #>

    [CmdletBinding()]
    param (
        [parameter(mandatory, ParameterSetName = "Name")]
        [string]$Name 
    )

    Begin {
        Get-TokenValidity

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings?`$filter=displayName+eq+'$($Name)'"

        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader

        if ($null -eq $result) {
            Write-Error "No User Settings Policy's returned"
            break
        }

        $Convert = $result.content | ConvertFrom-Json

        $assignmenturl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings/$($Convert.value.id)?`$expand=assignments"

        Write-Verbose "Asssingment URL: $assignmenturl"


    }
    Process {
        $Assignments = Invoke-WebRequest -uri $assignmenturl -Method GET -Headers $script:authHeader
    
        if ($null -eq $Assignments) {
            Write-Error "No Assignments for User Settings Policy $($Name) returned"
            break
        }

        $Convert = $Assignments | ConvertFrom-Json

        Write-Verbose "Convert: $Convert"

        Write-Verbose "Assignments: $($Convert.assignments)"

        Get-AzureADGroupName -id $Convert.assignments.target.groupId
    
        $Info = [PSCustomObject]@{
            id            = $Convert.id
            displayName   = $Convert.displayName
            assignments   = $script:GroupName
        }
        $Info  
    }
}