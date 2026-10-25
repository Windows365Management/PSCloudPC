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

        $Policy = @(Get-CPCProvisioningPolicy -Name $Name)

        if ($Policy.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Provisioning Policy found with name '$Name'" -Category ObjectNotFound
        }

        if ($Policy.Count -gt 1) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($Policy.Count) Provisioning Policies found with name '$Name' ($($Policy.id -join ', ')). The name must match exactly one policy."
        }

        $Policy = $Policy[0]

        if (-not (Test-Path -Path $OutputFolder -PathType Container)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Output folder '$OutputFolder' does not exist" -Category ObjectNotFound
        }
    }

    Process {

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($Policy.id)"

        write-verbose $url

        try {
            $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
        }
        catch {
            Throw (Get-GraphErrorMessage $_)
        }

        $Convert = ConvertFrom-Json $result.Content

        $JSON = ConvertTo-Json @($Convert) -Depth 100

        # Join-Path builds a path that is valid on Windows, macOS and Linux
        $OutputFile = Join-Path -Path $OutputFolder -ChildPath "$($Policy.displayName).json"
        Write-Verbose "Writing policy to $OutputFile"
        $JSON | Set-Content -Path $OutputFile

        Get-Item -Path $OutputFile
    }

}
