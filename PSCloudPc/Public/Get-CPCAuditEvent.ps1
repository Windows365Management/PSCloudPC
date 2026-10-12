function Get-CPCAuditEvent {
    <#
    .SYNOPSIS
    Returns Cloud PC audit events
    .DESCRIPTION
    The function will return all Cloud PC audit events, or audit events filtered
    by activity type. Audit events record every create, update, and delete
    operation performed on Cloud PC resources and are useful for compliance,
    troubleshooting, and change tracking. All result pages are returned.

    Optionally use -Top to limit the number of results returned (audit logs
    can grow large in active tenants).
    .PARAMETER Activity
    Return only audit events whose activityType (or activity, when Graph fills it)
    equals this value, e.g. "Create CloudPcUserSetting" or
    "AssignToGroups CloudPcProvisioningPolicy". The match is exact and
    case-insensitive and is done on the client, because Graph leaves the activity
    property empty. Use Get-CPCAuditEvent first to discover the activity types in
    your tenant.
    .PARAMETER Top
    Limit the number of audit events returned. When omitted all events are returned.
    .EXAMPLE
    Get-CPCAuditEvent
    .EXAMPLE
    Get-CPCAuditEvent -Top 25
    .EXAMPLE
    Get-CPCAuditEvent -Activity "Create CloudPcUserSetting"
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission
    (delegated or application).
    API reference: https://learn.microsoft.com/graph/api/virtualendpoint-list-auditevents?view=graph-rest-beta
    Resource: https://learn.microsoft.com/graph/api/resources/cloudpcauditevent?view=graph-rest-beta
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

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/auditEvents"
        $maxItems = 0

        if ($PSBoundParameters.ContainsKey("Activity")) {
            # Graph returns activity as null and puts the text in activityType, so filter on the client.
            # With -Activity every page is read and -Top is applied after filtering.
            Write-Verbose "Activity filter provided: $Activity"
        }
        elseif ($PSBoundParameters.ContainsKey("Top")) {
            $url = "$url`?`$top=$Top"
            $maxItems = $Top
        }
    }

    Process {
        $events = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET -MaxItems $maxItems)

        if ($PSBoundParameters.ContainsKey("Activity")) {
            $events = @($events | Where-Object { $_.activityType -eq $Activity -or $_.activity -eq $Activity })
            Write-Verbose "$($events.Count) audit events with activity type '$Activity'"
        }

        if ($PSBoundParameters.ContainsKey("Top")) {
            $events = @($events | Select-Object -First $Top)
        }

        foreach ($auditEvent in $events) {
            [PSCustomObject]@{
                id                    = $auditEvent.id
                displayName           = $auditEvent.displayName
                componentName         = $auditEvent.componentName
                activity              = $auditEvent.activity
                activityDateTime      = $auditEvent.activityDateTime
                activityOperationType = $auditEvent.activityOperationType
                activityResult        = $auditEvent.activityResult
                activityType          = $auditEvent.activityType
                category              = $auditEvent.category
                correlationId         = $auditEvent.correlationId
                actor                 = $auditEvent.actor
                resources             = $auditEvent.resources
            }
        }
    }

}
