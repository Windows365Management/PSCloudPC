Function Disconnect-Windows365 {
    <#
    .SYNOPSIS
    Disconnects from Windows 365 and clears the token cache.
    .DESCRIPTION
    Disconnects from Windows 365 and clears the token cache.
    .EXAMPLE
    Disconnect-Windows365
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param()

    begin {
        $Context = Get-MgContext -ErrorAction SilentlyContinue
        Write-Verbose "MGContext: $($Context)"
    }
    process {
        if ($PSCmdlet.ShouldProcess("Windows 365", "Disconnect and clear the token cache")) {
            Disconnect-MgGraph -ErrorAction SilentlyContinue
            $script:Authtime = $null
            $script:Authtoken = $null
            $script:Authheader = $null
            Write-Verbose "Disconnected from Windows 365"
        }
    }
}
