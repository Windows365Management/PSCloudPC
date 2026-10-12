function Export-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Exports a Provisioning Policy with a specific name to a JSON file
    .DESCRIPTION
    The function exports the Provisioning Policy with a specific name to a JSON file named
    after the policy in the output folder. The name must match exactly one Provisioning Policy;
    when it matches none or more than one, the command stops and no file is written.
    Characters that aren't valid in a file name (including path separators) are replaced with "_",
    and the file is only written inside the output folder. An existing file with the same name is
    overwritten after a warning. The export includes evolvable enum values such as the
    provisioningType sharedByUser, sharedByEntraGroup and reserve (Prefer: include-unknown-enum-members).
    .PARAMETER name
    Enter the name of the Provisioning Policy
    .PARAMETER OutputFolder
    Enter the folder where the JSON file is written
    .EXAMPLE
    Export-CPCProvisioningPolicy -name "ProvisioningPolicy01" -OutputFolder "C:\Temp"
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    API reference: https://learn.microsoft.com/graph/api/cloudpcprovisioningpolicy-get?view=graph-rest-beta
    Evolvable enums: https://learn.microsoft.com/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
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
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Provisioning Policy '$Name' not found. Use Get-CPCProvisioningPolicy to list the policies." -Category ObjectNotFound
        }

        if ($Policy.Count -gt 1) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($Policy.Count) Provisioning Policies found with name '$Name' ($($Policy.id -join ', ')). Rename one of them to export it."
        }

        $Policy = $Policy[0]

        # The file name comes from the tenant's displayName: replace characters that aren't valid in a file name on
        # any platform (including path separators), so the name can't point outside the output folder
        $invalidChars = [System.Collections.Generic.HashSet[char]]::new([char[]][System.IO.Path]::GetInvalidFileNameChars())
        foreach ($invalidChar in [char[]]"<>:`"/\|?*") {
            [void]$invalidChars.Add($invalidChar)
        }
        $fileName = -join (([string]$Policy.displayName).ToCharArray() | ForEach-Object {
                if ($invalidChars.Contains($_) -or [char]::IsControl($_)) { "_" } else { $_ }
            })
        # Leading dots would make a hidden file on macOS/Linux; trailing dots are dropped by Windows
        $fileName = $fileName.Trim().Trim(".")
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            $fileName = "ProvisioningPolicy-$([string]$Policy.id -replace "[^A-Za-z0-9-]", "_")"
        }
        if ($fileName -match "^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(\..*)?$") {
            $fileName = "_$fileName"
        }
        if ($fileName -ne $Policy.displayName) {
            Write-Verbose "Policy name '$($Policy.displayName)' is saved as file name '$fileName.json'"
        }

        $folderPath = [System.IO.Path]::GetFullPath($PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputFolder))
        $filePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($folderPath, "$fileName.json"))
        $folderPrefix = $folderPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

        if (-not $filePath.StartsWith($folderPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The export path '$filePath' is outside the output folder '$folderPath'. No file is written."
        }
    }

    Process {

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$([uri]::EscapeDataString([string]$Policy.id))/"

        write-verbose $url

        # Without this header Graph returns unknownFutureValue for evolvable enum members such as
        # provisioningType sharedByUser, sharedByEntraGroup and reserve
        $headers = $script:Authheader.Clone()
        $headers["Prefer"] = "include-unknown-enum-members"

        # Stop (not Throw) on a Graph error, so -ErrorAction SilentlyContinue can't let an empty result overwrite the file
        $result = $null
        $requestError = $null
        try {
            $result = Invoke-WebRequest -uri $url -Method GET -Headers $headers -ErrorAction Stop
        }
        catch {
            $requestError = Get-GraphErrorMessage $_
        }
        if ($null -ne $requestError) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message $requestError -Category InvalidOperation
        }
        if ($null -eq $result -or [string]::IsNullOrWhiteSpace([string]$result.Content)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Provisioning Policy returned for id $($Policy.id). No file is written." -Category InvalidResult
        }

        $Convert = ConvertFrom-Json $result.Content

        $JSON = ConvertTo-Json @($Convert) -Depth 100

        if (Test-Path -LiteralPath $filePath) {
            Write-Warning "Overwriting the existing file '$filePath'"
        }

        $JSON | Set-Content -LiteralPath $filePath
    }

}
