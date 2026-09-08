using namespace System.Net

# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform.
$rg = "sora-campaign-$DID"
$expectedDeploymentName = "sora2-campaign"
$expectedModelName = "sora-2"
$count = 0
$found = $false
$lastFailure = "Sora 2 deployment '$expectedDeploymentName' was not found in RG '$rg'."

function Get-NestedPropertyValue {
    param(
        [Parameter(Mandatory = $false)]
        [object] $InputObject,

        [Parameter(Mandatory = $true)]
        [string[]] $Path
    )

    $current = $InputObject
    foreach ($segment in $Path) {
        if ($null -eq $current) {
            return $null
        }

        if ($current -is [System.Collections.IDictionary]) {
            $matchingKey = $current.Keys | Where-Object { [string]$_ -ieq $segment } | Select-Object -First 1
            if ($null -eq $matchingKey) {
                return $null
            }
            $current = $current[$matchingKey]
        }
        else {
            $property = $current.PSObject.Properties | Where-Object { $_.Name -ieq $segment } | Select-Object -First 1
            if ($null -eq $property) {
                return $null
            }
            $current = $property.Value
        }
    }

    return $current
}

function Get-ResourceWithFallbackApiVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResourceId,

        [Parameter(Mandatory = $true)]
        [string[]] $ApiVersions
    )

    foreach ($apiVersion in $ApiVersions) {
        try {
            $resource = Get-AzResource -ResourceId $ResourceId -ApiVersion $apiVersion -ExpandProperties -ErrorAction Stop
            if ($null -ne $resource) {
                return $resource
            }
        }
        catch {
            # Continue to the next API version. Sora 2 deployment metadata can be preview-dependent.
        }
    }

    return $null
}

do {
    $count = $count + 1
    try {
        Set-AzContext -Subscription $sub -ErrorAction Stop | Out-Null

        $resourceGroup = Get-AzResourceGroup -Name $rg -ErrorAction SilentlyContinue
        if ($null -eq $resourceGroup) {
            $lastFailure = "Expected resource group '$rg' was not found in subscription '$sub'."
        }
        else {
            try {
                $accounts = @(Get-AzResource -ResourceGroupName $rg -ResourceType "Microsoft.CognitiveServices/accounts" -ApiVersion "2025-06-01" -ExpandProperties -ErrorAction Stop)
            }
            catch {
                $accounts = @(Get-AzResource -ResourceGroupName $rg -ResourceType "Microsoft.CognitiveServices/accounts" -ExpandProperties -ErrorAction Stop)
            }

            if ($accounts.Count -eq 0) {
                $lastFailure = "No Microsoft.CognitiveServices/accounts resources were found in RG '$rg'."
            }
            else {
                $compatibleAccounts = @()
                foreach ($account in $accounts) {
                    $accountKind = [string](Get-NestedPropertyValue -InputObject $account -Path @("Kind"))
                    if ([string]::IsNullOrWhiteSpace($accountKind)) {
                        $accountKind = [string](Get-NestedPropertyValue -InputObject $account -Path @("Properties", "kind"))
                    }

                    if ($accountKind -in @("AIServices", "OpenAI")) {
                        $compatibleAccounts += $account
                    }
                }

                if ($compatibleAccounts.Count -eq 0) {
                    $accountNames = ($accounts | ForEach-Object { "$($_.Name) (kind: $($_.Kind))" }) -join ", "
                    $lastFailure = "Cognitive Services resources were found in RG '$rg', but none were Foundry-compatible kind 'AIServices' or 'OpenAI'. Found: $accountNames."
                }
                else {
                    foreach ($account in $compatibleAccounts) {
                        $deploymentResourceId = "$($account.ResourceId)/deployments/$expectedDeploymentName"
                        $deployment = Get-ResourceWithFallbackApiVersion -ResourceId $deploymentResourceId -ApiVersions @("2025-07-01-preview", "2025-06-01", "2023-05-01")

                        if ($null -eq $deployment) {
                            continue
                        }

                        $modelName = [string](Get-NestedPropertyValue -InputObject $deployment -Path @("Properties", "model", "name"))
                        $modelFormat = [string](Get-NestedPropertyValue -InputObject $deployment -Path @("Properties", "model", "format"))
                        $modelVersion = [string](Get-NestedPropertyValue -InputObject $deployment -Path @("Properties", "model", "version"))
                        $provisioningState = [string](Get-NestedPropertyValue -InputObject $deployment -Path @("Properties", "provisioningState"))

                        if (-not [string]::IsNullOrWhiteSpace($modelName) -and $modelName -ne $expectedModelName) {
                            $lastFailure = "Deployment '$expectedDeploymentName' exists under account '$($account.Name)' in RG '$rg', but its model is '$modelName' instead of expected model '$expectedModelName'."
                            continue
                        }

                        if (-not [string]::IsNullOrWhiteSpace($provisioningState) -and $provisioningState -in @("Failed", "Canceled", "Cancelled", "Deleting")) {
                            $lastFailure = "Deployment '$expectedDeploymentName' exists under account '$($account.Name)' in RG '$rg', but provisioning state is '$provisioningState'."
                            continue
                        }

                        $found = $true
                        $stateText = if ([string]::IsNullOrWhiteSpace($provisioningState)) { "provisioning state not exposed by the current preview API" } else { "provisioning state '$provisioningState'" }
                        $modelText = if ([string]::IsNullOrWhiteSpace($modelName)) { "model metadata not exposed by the current preview API" } else { "model '$modelName'" }
                        $formatText = if ([string]::IsNullOrWhiteSpace($modelFormat)) { "format not exposed" } else { "format '$modelFormat'" }
                        $versionText = if ([string]::IsNullOrWhiteSpace($modelVersion)) { "version not exposed" } else { "version '$modelVersion'" }

                        $message = @{
                            Status  = "Succeeded"
                            Message = "Found Foundry-compatible Cognitive Services account '$($account.Name)' (kind '$($account.Kind)') in RG '$rg' with deployment '$expectedDeploymentName' as Microsoft.CognitiveServices/accounts/deployments; $modelText, $formatText, $versionText, $stateText."
                        } | ConvertTo-Json
                        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                            StatusCode = [HttpStatusCode]::OK
                            Body       = $message
                        })
                        break
                    }

                    if (-not $found -and $lastFailure -eq "Sora 2 deployment '$expectedDeploymentName' was not found in RG '$rg'.") {
                        $compatibleAccountNames = ($compatibleAccounts | ForEach-Object { $_.Name }) -join ", "
                        $lastFailure = "Deployment '$expectedDeploymentName' was not found as a Microsoft.CognitiveServices/accounts/deployments child resource under Foundry-compatible account(s) in RG '$rg': $compatibleAccountNames."
                    }
                }
            }
        }

        if (-not $found) {
            $message = @{
                Status  = "Failed"
                Message = "$lastFailure Attempt $count of 3."
            } | ConvertTo-Json
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = $message
            })

            if ($count -lt 3) {
                Start-Sleep -Seconds 10
            }
        }
    }
    catch {
        $lastFailure = "Error during check. Attempt $count of 3. Error: $($_.Exception.Message)"
        $message = @{
            Status  = "Failed"
            Message = $lastFailure
        } | ConvertTo-Json
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $message
        })
        Start-Sleep -Seconds 10
    }
} while ($count -lt 3 -and -not $found)

# Post-loop: if every attempt failed, emit a final failure JSON so CloudLabs always sees a structured result.
if (-not $found) {
    $message = @{
        Status  = "Failed"
        Message = "Sora 2 deployment '$expectedDeploymentName' not found or not valid in Foundry-compatible Cognitive Services account in RG '$rg' after 3 attempts. Last detail: $lastFailure"
    } | ConvertTo-Json
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $message
    })
}
