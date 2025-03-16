Function Disconnect-Windows365 {
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
    Process {

        If ($Context) {
            
            Write-Verbose "Connected using Disconnecting from Windows 365"
            Disconnect-MgGraph

        }
        
        Write-Verbose "Clear token cache"
        $script:Authtime = $null
        $script:Authtoken = $null
        $script:Authheader = $null
    }
    
}