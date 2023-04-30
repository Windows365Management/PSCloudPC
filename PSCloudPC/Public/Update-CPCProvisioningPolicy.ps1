function Update-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Update a Cloud PC Provisioning Policy
    .DESCRIPTION
    Update a Cloud PC Provisioning Policy
    .PARAMETER Name
    Name of the Provisioning Policy to update an image for example
    .PARAMETER ImageType
    Type of image to use for the Cloud PC. Valid values are Custom or Gallery
    .PARAMETER ImageId
    Id of the image to use for the Cloud PC. This is the Id of the image in the gallery or the custom image
    .PARAMETER EnableSingleSignOn
    Enable Single Sign On for the Cloud PC
    .PARAMETER NamingTemplate
    Naming template for the Cloud PC
    .PARAMETER AzureNetworkConnection
    Azure Network Connection to use for the Cloud PC (It will replace current Azure Network Connection)
    .EXAMPLE
    Update-CPCProvisioningPolicy -Name "Test-AzureADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" 
    .EXAMPLE
    Update-CPCProvisioningPolicy -Name "Test-AzureADJoin" -EnableSingleSignOn $true
    .NOTES
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,

        [ValidateSet("Custom","Gallery")]
        [parameter(Mandatory = $false)][string]$ImageType,

        [parameter(Mandatory = $false)][string]$ImageId,

        [parameter(Mandatory = $false)][bool]$EnableSingleSignOn,

        [parameter(Mandatory = $false)][string]$NamingTemplate,

        [parameter(Mandatory = $false)][object]$AzureNetworkConnection,

        [ValidateSet('azureADJoin', 'hybridAzureADJoin')]
        [string]$DomainJoinType = 'azureADJoin'
    )

    Begin {
        Get-TokenValidity

        $Policy = Get-CPCProvisioningPolicy -name $Name

        If ($null -eq $Policy) {
            Throw "No User Settings Policy found with name $Name"
            return
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($Policy.id)"

        Write-Verbose "Update url: $($url)"

    }

    Process {
        
        $params = @{
            displayName = $($Policy.displayName)
        }

        If ($ImageId){
            $params.Add("ImageType","$imageType")
            $params.Add("ImageId", "$ImageId")
        }

        If ($psboundparameters.ContainsKey("EnableSingleSignOn")){
            $params.Add("EnableSingleSignOn", $EnableSingleSignOn)
        }
 
        If ($NamingTemplate){
            $params.Add("CloudPcNamingTemplate","$NamingTemplate")
        }

        If ($AzureNetworkConnection) {
            $domainJoinConfigurations = @()
            foreach ($Network in $AzureNetworkConnection) {

                $AzureNetworkInfo = Get-CPCAzureNetworkConnection -Name $Network

                If ($null -eq $AzureNetworkInfo) {
                    Throw "No Azure Network Connection found with name $Network"
                    break
                }

                if ($AzureNetworkInfo.healthCheckStatus -ne "passed") {
                    Throw "Azure Network Connection $Network is not healthy"
                    break
                }

                Write-Verbose "AzureNetworkConnection ID: $($AzureNetworkInfo.Id)"
                $domainJoinConfig = @{
                    Type                   = $AzureNetworkInfo.Type
                    OnPremisesConnectionId = $AzureNetworkInfo.Id
                }
                $domainJoinConfigurations += $domainJoinConfig
            }
            $params.Add("DomainJoinConfigurations", $domainJoinConfigurations)
        }
        
        Write-Verbose "Params: $($params)"

        $body = $params | ConvertTo-Json -Depth 10

        Write-Verbose "Body: $($body)"

        try {
            Write-Verbose "Updating User Settings Policy $($Name)"
            $Result = Invoke-WebRequest -uri $url -Method PATCH -Headers $script:authHeader -Body $body -ContentType "application/json" -SkipHttpErrorCheck
            Write-Verbose "Result: $($Result.Content)"
        }
        catch {
            Throw $_.Exception.Message
        }
    }
}