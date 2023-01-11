function Invoke-CPCEndGracePeriod {
    <#
        .SYNOPSIS
        Function to end the grace period of a CloudPC
        .DESCRIPTION
        Function to end the grace period of a CloudPC
        .PARAMETER name
        Name of the CloudPC to end the grace period of
        .PARAMETER Force
        Force parameter to end the grace period of all CloudPCs
        .EXAMPLE
        Invoke-CPCEndGracePeriod -Name "CloudPC01"
        .EXAMPLE
        Invoke-CPCEndGracePeriod -All -Force
    #>

    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [parameter(Mandatory, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All,

        [Parameter()][switch]$Force
    )
        
    Begin {
        Get-TokenValidity
    
    }
        
    Process {
        switch ($PsCmdlet.ParameterSetName) {
            Name {  
                $CloudPCs = Get-CloudPC -name $Name | Where-Object { $_.status -eq "inGracePeriod" }
                Write-Verbose "Getting Single CloudPC inGracePeriod: $($CloudPCs.managedDeviceName)"

                If ($null -eq $CloudPCs) {
                    Throw "No CloudPC found in grace period with name $Name"
                    return
                }
                
            }

            All {
                $CloudPCs = Get-CloudPC | Where-Object { $_.status -eq "inGracePeriod" }
                Write-Verbose "Getting every CloudPC inGracePeriod: $($CloudPCs.managedDeviceName)"

                If ($null -eq $CloudPCs) {
                    Throw "No CloudPC found in grace period with name"
                    return
                }

            }
        }

        $Count = $CloudPCs.count

        if ($Force){
            $CloudPCs | ForEach-Object {
                try {
                    $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($_.id)/endGracePeriod"
                    
                    Write-Verbose "End Grace Period $($_.managedDeviceName) url: $($url)"

                    Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST 

                    Write-Output "End Grace Period $($_.managedDeviceName)"
                }                                       
                catch {
                    Throw $_.Exception.Message
                }
            }
        }
        else {

            Write-Output "$($Count) CloudPC(s) found in grace period" -ForegroundColor Yellow
            $choice = Read-Host "Are you sure you want to end the grace period for CloudPC(s)? (y/n)"
            if ($choice -ne "y") {
                Write-Output "Exiting script"
                return
            }
            
            $CloudPCs | ForEach-Object {
                try {
                    $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($_.id)/endGracePeriod"
    
                    Write-Verbose "End Grace Period $($_.displayName) url: $($url)"
    
                    Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST

                    Write-Output "End Grace Period $($_.managedDeviceName)"
                }
                catch {
                    Throw $_.Exception.Message
                }
            }
        }

    }
}
        
