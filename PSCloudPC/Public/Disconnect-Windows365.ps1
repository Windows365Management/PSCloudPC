Function Disconnect-Windows365 {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

    <#
    .SYNOPSIS
    Disconnects from Windows 365 and clears the token cache.
    .DESCRIPTION
    Disconnects from Windows 365 and clears the token cache.
    .EXAMPLE
    Disconnect-Windows365
    #>

    begin {
        $Context = Get-MGContext
        Write-Verbose "MGContext: $($Context)"
    }
    process {
        if ($Context) {
            if ($PSCmdlet.ShouldProcess("Windows 365 session", "Disconnect")) {
                Write-Verbose "Disconnecting from Windows 365"
                try {
                    Disconnect-MgGraph
                    Write-Verbose "Disconnected from Windows 365"
                }
                catch {
                    Write-Error "Failed to disconnect from Windows 365, Error: $($_.Exception.Message)"
                }
            }
        }
        try {
            $script:Authtime = $null
            $script:Authtoken = $null
            $script:Authheader = $null
            Write-Verbose "Cleared token cache"
        }
        catch {
            Write-Error "Failed to clear token cache, Error: $($_.Exception.Message)"
        }
    }
}
