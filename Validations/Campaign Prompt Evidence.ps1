using namespace System.Net

# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform.
$rg = "rg-sora-campaign-$DID"
$count = 0
$found = $false
$lastFailure = "Campaign prompt evidence was not validated."

$vmName = "labvm-$DID"
$labPathDisplay = "Windows lab folder LabFiles\SoraCampaign"
$worksheetDisplay = "Campaign-Worksheet.md"
$evidenceFolderDisplay = "Evidence"

$remoteValidationScript = @'
$ErrorActionPreference = 'Stop'

$labRoot = Join-Path -Path $env:SystemDrive -ChildPath 'LabFiles\SoraCampaign'
$rootWorksheetPath = Join-Path -Path $labRoot -ChildPath 'Campaign-Worksheet.md'
$evidenceFolderPath = Join-Path -Path $labRoot -ChildPath 'Evidence'
$evidenceWorksheetPath = Join-Path -Path $evidenceFolderPath -ChildPath 'Campaign-Worksheet.md'
$allowedExtensions = @('.mp4', '.png', '.jpg', '.jpeg', '.webp', '.txt')

$rootWorksheetExists = Test-Path -LiteralPath $rootWorksheetPath -PathType Leaf
$evidenceFolderExists = Test-Path -LiteralPath $evidenceFolderPath -PathType Container
$evidenceWorksheetExists = Test-Path -LiteralPath $evidenceWorksheetPath -PathType Leaf

$worksheetPathToInspect = $null
if ($evidenceWorksheetExists) {
    $worksheetPathToInspect = $evidenceWorksheetPath
}
elseif ($rootWorksheetExists) {
    $worksheetPathToInspect = $rootWorksheetPath
}

$hasBaselinePromptSection = $false
$hasRefinedPromptSection = $false
$worksheetContainsCampaignPromptText = $false
$worksheetLength = 0

if ($worksheetPathToInspect) {
    $worksheetContent = Get-Content -LiteralPath $worksheetPathToInspect -Raw -ErrorAction Stop
    $worksheetLength = $worksheetContent.Length
    $hasBaselinePromptSection = ($worksheetContent -match '(?im)^\s{0,6}#{0,6}\s*(?:[-*]\s*)?baseline\s+prompt\b') -or ($worksheetContent -match '(?i)baseline\s+prompt')
    $hasRefinedPromptSection = ($worksheetContent -match '(?im)^\s{0,6}#{0,6}\s*(?:[-*]\s*)?refined\s+prompt\b') -or ($worksheetContent -match '(?i)refined\s+prompt')
    $worksheetContainsCampaignPromptText = ($worksheetContent -match '(?i)eco-friendly\s+reusable\s+water\s+bottle') -or ($worksheetContent -match '(?i)EcoSip') -or ($worksheetContent -match '(?i)promotional\s+video')
}

$evidenceArtifacts = @()
if ($evidenceFolderExists) {
    $evidenceArtifacts = @(Get-ChildItem -LiteralPath $evidenceFolderPath -File -ErrorAction Stop | Where-Object {
        $allowedExtensions -contains $_.Extension.ToLowerInvariant() -and $_.Length -gt 0
    } | Select-Object -ExpandProperty Name)
}

$success = $rootWorksheetExists -and $evidenceFolderExists -and $worksheetPathToInspect -and $hasBaselinePromptSection -and $hasRefinedPromptSection -and $worksheetContainsCampaignPromptText -and ($evidenceArtifacts.Count -ge 1)

$missingItems = New-Object System.Collections.Generic.List[string]
if (-not $rootWorksheetExists) { [void]$missingItems.Add("Root worksheet missing: $rootWorksheetPath") }
if (-not $evidenceFolderExists) { [void]$missingItems.Add("Evidence folder missing: $evidenceFolderPath") }
if (-not $worksheetPathToInspect) { [void]$missingItems.Add('No worksheet available to inspect in the root lab folder or Evidence folder') }
if ($worksheetPathToInspect -and -not $hasBaselinePromptSection) { [void]$missingItems.Add("Worksheet missing a Baseline prompt section: $worksheetPathToInspect") }
if ($worksheetPathToInspect -and -not $hasRefinedPromptSection) { [void]$missingItems.Add("Worksheet missing a Refined prompt section: $worksheetPathToInspect") }
if ($worksheetPathToInspect -and -not $worksheetContainsCampaignPromptText) { [void]$missingItems.Add('Worksheet does not appear to contain campaign prompt text for the EcoSip/reusable bottle video') }
if ($evidenceFolderExists -and $evidenceArtifacts.Count -lt 1) { [void]$missingItems.Add("No non-empty text-to-video evidence artifact with extension .mp4, .png, .jpg, .jpeg, .webp, or .txt found in $evidenceFolderPath") }

$result = [pscustomobject]@{
    Success = $success
    RootWorksheetPath = $rootWorksheetPath
    RootWorksheetExists = $rootWorksheetExists
    EvidenceFolderPath = $evidenceFolderPath
    EvidenceFolderExists = $evidenceFolderExists
    WorksheetInspected = $worksheetPathToInspect
    WorksheetLength = $worksheetLength
    HasBaselinePromptSection = $hasBaselinePromptSection
    HasRefinedPromptSection = $hasRefinedPromptSection
    HasCampaignPromptText = $worksheetContainsCampaignPromptText
    EvidenceArtifacts = $evidenceArtifacts
    MissingItems = @($missingItems)
}

Write-Output ("VALIDATION_RESULT_BEGIN" + ($result | ConvertTo-Json -Depth 5 -Compress) + "VALIDATION_RESULT_END")
'@

do {
    $count = $count + 1
    try {
        Set-AzContext -Subscription $sub -ErrorAction Stop

        $vm = $null
        $resourceGroup = Get-AzResourceGroup -Name $rg -ErrorAction SilentlyContinue
        if ($resourceGroup) {
            $vm = Get-AzVM -ResourceGroupName $rg -Name $vmName -ErrorAction SilentlyContinue
        }

        if (-not $vm) {
            $vmResource = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines" -ErrorAction Stop | Where-Object {
                $_.Name -eq $vmName -or ($_.Tags -and $_.Tags.ContainsKey('DeploymentID') -and $_.Tags['DeploymentID'] -eq $DID)
            } | Select-Object -First 1

            if ($vmResource) {
                $rg = $vmResource.ResourceGroupName
                $vmName = $vmResource.Name
                $vm = Get-AzVM -ResourceGroupName $rg -Name $vmName -ErrorAction Stop
            }
        }

        if ($vm) {
            $runResult = Invoke-AzVMRunCommand -ResourceGroupName $rg -VMName $vmName -CommandId "RunPowerShellScript" -ScriptString $remoteValidationScript -ErrorAction Stop
            $runOutput = ($runResult.Value | ForEach-Object { $_.Message }) -join "`n"
            $match = [regex]::Match($runOutput, 'VALIDATION_RESULT_BEGIN(?<json>\{.*?\})VALIDATION_RESULT_END', [System.Text.RegularExpressions.RegexOptions]::Singleline)

            if ($match.Success) {
                $vmCheck = $match.Groups['json'].Value | ConvertFrom-Json
                if ($vmCheck.Success -eq $true) {
                    $found = $true
                    $artifactList = @($vmCheck.EvidenceArtifacts) -join ', '
                    $messageText = "Campaign prompt evidence found on VM '$vmName' in RG '$rg'. Worksheet '$($vmCheck.WorksheetInspected)' exists and contains Baseline prompt and Refined prompt sections. Evidence folder '$($vmCheck.EvidenceFolderPath)' contains artifact(s): $artifactList."
                }
                else {
                    $missing = @($vmCheck.MissingItems) -join '; '
                    $lastFailure = "Campaign prompt evidence is incomplete on VM '$vmName' in RG '$rg'. $missing"
                    $messageText = $lastFailure
                }
            }
            else {
                $lastFailure = "Run command completed on VM '$vmName' in RG '$rg', but the validator could not parse the result. Raw output: $runOutput"
                $messageText = $lastFailure
            }
        }
        else {
            $lastFailure = "Lab VM '$vmName' was not found in subscription '$sub'. Expected a CloudLabs Windows VM named labvm-$DID."
            $messageText = $lastFailure
        }

        if ($found) {
            $message = @{
                Status  = "Succeeded"
                Message = $messageText
            } | ConvertTo-Json
        } else {
            $message = @{
                Status  = "Failed"
                Message = $messageText
            } | ConvertTo-Json
        }
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $message
        })

        if (-not $found -and $count -lt 3) {
            Start-Sleep -Seconds 10
        }
    }
    catch {
        $lastFailure = "Error during campaign prompt evidence check. Attempt $count of 3. Error: $($_.Exception.Message)"
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

# Post-loop: if every attempt failed, emit a final failure JSON so CloudLabs
# always sees a structured result.
if (-not $found) {
    $message = @{
        Status  = "Failed"
        Message = "Campaign prompt evidence not found after 3 attempts. Expected worksheet '$worksheetDisplay', folder '$evidenceFolderDisplay' under '$labPathDisplay', Baseline prompt and Refined prompt worksheet sections, and at least one non-empty .mp4, .png, .jpg, .jpeg, .webp, or .txt artifact in the Evidence folder. Last result: $lastFailure"
    } | ConvertTo-Json
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $message
    })
}
