Function Import-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Imports a Provisioning Policy from a JSON File
    .DESCRIPTION
    The function will import a Provisioning Policy from a JSON File
    .PARAMETER Inputfile
        Enter the path to the JSON File
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ParameterSetName = "Name")]
        [string]$Inputfile
    )
    
    Begin {
        Get-TokenValidity

        if (-not (Test-Path -Path $Inputfile)) {
            Write-Error "File not found"
            break
        }

    }
    
    Process {
        
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/"

        write-verbose $url

        #Inserting New Version into JSON File
        $Content = Get-Content -Path $Inputfile #| ConvertFrom-Json
        # Remove properties that are not available for creating a new configuration
        $JSON_Convert = $Content | ConvertFrom-Json
        $JSON_Output = $JSON_Convert | Select-Object -Property * -ExcludeProperty id, scopeIds | ConvertTo-Json -Depth 100

        Write-Verbose "JSON: $JSON_Output"

        try {
            Invoke-WebRequest -uri $url -Method POST -Headers $script:authHeader -Body $JSON_Output -ContentType "application/json"
        }
        catch {
            Throw $_.Exception.Message
        }
        

    }
    
}
