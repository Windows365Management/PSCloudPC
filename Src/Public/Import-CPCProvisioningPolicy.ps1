Function Import-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Imports a Provisioning Policy from a JSON File
    .DESCRIPTION
    The function will import a Provisioning Policy from a JSON File
    .PARAMETER Inputfile
    Enter the path to the JSON File
    .EXAMPLE
    Import-CPCProvisioningPolicy -Inputfile "C:\Temp\AzureADJoinPolicy.json"
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
        # Get the JSON File and convert it to a PSObject
        $Content = Get-Content -Path $Inputfile | ConvertFrom-Json
    
        if ($null -eq $Content) {
            Write-Error "InputFile is not a valid JSON File"
        }
                

    }
    
    Process {
        
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/"

        write-verbose $url

        if (($Content.domainJoinConfigurations.type -eq 'azureADJoin') -and ($null -eq $Content.domainJoinConfigurations.onPremisesConnectionId)) {

            write-verbose "Importing AzureADJoin policy without onPremisesConnectionId"
            
            New-CPCProvisioningPolicy -Name $Content.displayName -Description $Content.description -DomainJoinType $Content.domainJoinConfigurations.Type -ImageType $Content.imageType -ImageId $Content.imageId -EnableSingleSignOn $Content.enableSingleSignOn -RegionGroup $Content.domainJoinConfigurations.RegionGroup -RegionName $Content.domainJoinConfigurations.RegionName -Language $Content.windowsSettings.language -NamingTemplate $Content.cloudPcNamingTemplate -ProvisioningType $Content.provisioningType
        }
        if (($Content.domainJoinConfigurations.type -eq 'azureADJoin') -and ($null -ne $Content.domainJoinConfigurations.onPremisesConnectionId)) {

            Write-Verbose "Importing AzureADJoin policy with onPremisesConnectionId"

            $AzureNetworkConnection = Get-CPCAzureNetworkConnection | Where-Object id -eq $Content.domainJoinConfigurations.onPremisesConnectionId
            
            New-CPCProvisioningPolicy -Name $Content.displayName -Description $Content.description -DomainJoinType $Content.domainJoinConfigurations.Type -ImageType $Content.imageType -ImageId $Content.imageId -EnableSingleSignOn $Content.enableSingleSignOn -AzureNetworkConnection $AzureNetworkConnection.displayName -Language $Content.windowsSettings.language -NamingTemplate $Content.cloudPcNamingTemplate -ProvisioningType $Content.provisioningType
        }
        if ($Content.domainJoinConfigurations.type -eq 'hybridAzureADJoin') {

            Write-Verbose "Importing HybridAzureADJoin Policy"

            $AzureNetworkConnection = Get-CPCAzureNetworkConnection | Where-Object id -eq $Content.domainJoinConfigurations.onPremisesConnectionId

            New-CPCProvisioningPolicy -Name $Content.displayName -Description $Content.description -imageType $Content.imageType -ImageId $Content.imageId -DomainJoinType $Content.domainJoinConfigurations.type -EnableSingleSignOn $Content.enableSingleSignOn -AzureNetworkConnection $AzureNetworkConnection.displayName -Language $Content.windowsSettings.language -NamingTemplate $Content.cloudPcNamingTemplate -ProvisioningType $Content.provisioningType
        }
        
    }
    
}
