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
    .PARAMETER DomainJoinType
    Only used as a fallback when the Azure Network Connection does not report a connectionType; the join type of the policy follows the connection
    .EXAMPLE
    Update-CPCProvisioningPolicy -Name "Test-AzureADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" 
    .EXAMPLE
    Update-CPCProvisioningPolicy -Name "Test-AzureADJoin" -EnableSingleSignOn $true
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/cloudpcprovisioningpolicy-update?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
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

        $Policy = @(Get-CPCProvisioningPolicy -name $Name)

        If ($Policy.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Provisioning Policy found with name $Name" -Category ObjectNotFound
        }

        If ($Policy.Count -gt 1) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($Policy.Count) Provisioning Policies found with name $Name ($($Policy.id -join ', ')). The name must match exactly one policy."
        }

        $Policy = $Policy[0]

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($Policy.id)"

        Write-Verbose "Update url: $($url)"

    }

    Process {
        
        $params = @{
            displayName = $($Policy.displayName)
        }

        If ($PSBoundParameters.ContainsKey("ImageId")) {
            $params.Add("imageId", "$ImageId")
            # Keep the current image type when only a new image id is passed; an empty imageType is rejected by Graph
            If ($PSBoundParameters.ContainsKey("ImageType")) {
                $params.Add("imageType", $ImageType.ToLower())
            }
            ElseIf ($Policy.imageType) {
                $params.Add("imageType", $Policy.imageType)
            }
        }
        ElseIf ($PSBoundParameters.ContainsKey("ImageType")) {
            $params.Add("imageType", $ImageType.ToLower())
        }

        If ($PSBoundParameters.ContainsKey("EnableSingleSignOn")) {
            $params.Add("enableSingleSignOn", $EnableSingleSignOn)
        }
 
        If ($NamingTemplate) {
            $params.Add("cloudPcNamingTemplate", "$NamingTemplate")
        }

        If ($AzureNetworkConnection) {
            $domainJoinConfigurations = @()
            foreach ($Network in $AzureNetworkConnection) {

                $AzureNetworkInfo = @(Get-CPCAzureNetworkConnection -Name $Network)

                If ($AzureNetworkInfo.Count -eq 0) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Azure Network Connection found with name $Network" -Category ObjectNotFound
                }

                If ($AzureNetworkInfo.Count -gt 1) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($AzureNetworkInfo.Count) Azure Network Connections found with name $Network ($($AzureNetworkInfo.id -join ', ')). The name must match exactly one connection."
                }

                $AzureNetworkInfo = $AzureNetworkInfo[0]

                # Cloud PCs can be provisioned when the health check passed, or passed with a warning or informational result
                if ($AzureNetworkInfo.healthCheckStatus -notin @("passed", "warning", "informational")) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Azure Network Connection $Network is not healthy (healthCheckStatus: $($AzureNetworkInfo.healthCheckStatus))" -Category InvalidOperation
                }

                # The join type follows the connectionType of the connection (type stopped returning data on January 31, 2024)
                $JoinType = $AzureNetworkInfo.connectionType
                If ([string]::IsNullOrWhiteSpace($JoinType)) {
                    $JoinType = $DomainJoinType
                }

                Write-Verbose "AzureNetworkConnection ID: $($AzureNetworkInfo.Id), join type: $JoinType"
                $domainJoinConfigurations += @{
                    domainJoinType         = $JoinType
                    type                   = $JoinType
                    onPremisesConnectionId = $AzureNetworkInfo.Id
                }
            }
            $params.Add("domainJoinConfigurations", $domainJoinConfigurations)
        }

        $body = $params | ConvertTo-Json -Depth 10

        Write-Verbose "Body: $($body)"

        If ($PSCmdlet.ShouldProcess($Policy.displayName, "Update Provisioning Policy")) {
            try {
                Write-Verbose "Updating Provisioning Policy $($Name)"
                $Result = Invoke-WebRequest -uri $url -Method PATCH -Headers $script:authHeader -Body $body -ContentType "application/json"
                Write-Verbose "Result: $($Result.Content)"
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }
}
