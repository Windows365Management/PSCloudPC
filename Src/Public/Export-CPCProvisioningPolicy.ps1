function Export-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Returns all Provisioning Policy's or Provisioning Policy's with a specific name
    .DESCRIPTION
    The function will return all Provisioning Policy's or Provisioning Policy's with a specific name
    .PARAMETER name
    Enter the name of the Provisioning Policy
    .EXAMPLE
    Export-CPCProvisioningPolicy -name "ProvisioningPolicy01" -OutputFolder "C:\Temp"
#>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ParameterSetName = "Name")]
        [string]$Name,
        [parameter(Mandatory = $true, ParameterSetName = "Name")]
        [string]$OutputFolder
    )
    
    Begin {
        Get-TokenValidity

        $Policy = Get-CPCProvisioningPolicy -Name $Name

        if ($null -eq $Policy) {
            Write-Error "No Provisioning Policy's returned"
            break
        }
    }
    
    Process {

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($Policy.id)/"

        write-verbose $url

        try {
            $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
            if ($null -eq $result) {
                Write-Error "No Provisioning Policy returned"
                break
            }

            $Convert = ConvertFrom-Json $result.Content

            $JSON = ConvertTo-Json @($Convert) -Depth 100

            $JSON | Set-Content -Path "$($OutputFolder)\$($Policy.displayName).json"
        }
        catch {
            Throw $_.Exception.Message
        }
    }
    
}