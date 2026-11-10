function Export-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Exports a Cloud PC Provisioning Policy to a JSON file
    .DESCRIPTION
    The function will export the Provisioning Policy with the specified name to a JSON file named after the policy. Use Import-CPCProvisioningPolicy to import it.
    .PARAMETER name
    Enter the name of the Provisioning Policy
    .PARAMETER OutputFolder
    Enter the folder to save the JSON file in
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
            Throw (Get-GraphErrorMessage $_)
        }
    }

}