function Get-CPCAuditEvent {
    <#
    .SYNOPSIS
    Returns Cloud PC audit events
    .DESCRIPTION
    The function will return all Cloud PC audit events, or audit events filtered
    by activity name. Audit events record every create, update, and delete
    operation performed on Cloud PC resources and are useful for compliance,
    troubleshooting, and change tracking.

    Optionally use -Top to limit the number of results returned (audit logs
    can grow large in active tenants).
    .PARAMETER Activity
    Filter audit events by activity name, e.g. "Update cloudPC" or
    "Reprovision cloudPc". Use Get-CPCAuditEvent first to discover activity names
    in your tenant.
    .PARAMETER Top
    Limit the number of audit events returned. When omitted all events are returned.
    .EXAMPLE
    Get-CPCAuditEvent
    .EXAMPLE
    Get-CPCAuditEvent -Top 25
    .EXAMPLE
    Get-CPCAuditEvent -Activity "Reprovision cloudPc"
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission
    (delegated or application).
    API reference: https://learn.microsoft.com/en-us/graph/api/virtualendpoint-list-auditevents
    #>
    [CmdletBinding()]
    param (
        [parameter(ParameterSetName = "Activity")]
        [string]$Activity,

        [parameter()]
        [ValidateRange(1, 999)]
        [int]$Top
    )

    Begin {
        Get-TokenValidity

        $baseUrl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/auditEvents"

        $queryParams = @()

        switch ($PsCmdlet.ParameterSetName) {
            Activity {
                Write-Verbose "Activity filter provided: $Activity"
                $queryParams += "`$filter=activity+eq+'$($Activity)'"
            }
        }

        if ($PSBoundParameters.ContainsKey('Top')) {
            $queryParams += "`$top=$Top"
        }

        if ($queryParams.Count -gt 0) {
            $url = "$baseUrl`?$($queryParams -join '&')"
        }
        else {
            $url = $baseUrl
        }
    }

    Process {
        Write-Verbose $url

        try {
            $result = Invoke-WebRequest -Uri $url -Method GET -Headers $script:authHeader
        }
        catch {
            Throw $_.Exception.Message
        }

        if ($null -eq $result) {
            Write-Error "No audit events returned"
            return
        }

        $resultnew = $result.content | ConvertFrom-Json
        $returnResults = @()

        $resultnew.value | ForEach-Object {

            $Info = [PSCustomObject]@{
                id                    = $_.id
                displayName           = $_.displayName
                componentName         = $_.componentName
                activity              = $_.activity
                activityDateTime      = $_.activityDateTime
                activityOperationType = $_.activityOperationType
                activityResult        = $_.activityResult
                activityType          = $_.activityType
                category              = $_.category
                correlationId         = $_.correlationId
                actor                 = $_.actor
                resources             = $_.resources
            }
            $returnResults += $Info
        }
        return $returnResults

    }

}
