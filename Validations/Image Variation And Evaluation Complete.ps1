using namespace System.Net

# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform.
# The lab VM is deployed as labvm-$DID. The initial RG value follows the package scenario;
# the script also discovers the VM by name/tag in case the CloudLabs runtime supplied a different RG name.
$rg = "rg-sora-campaign-$DID"
$count = 0
$found = $false
$lastFailure = "Image variation and evaluation evidence was not validated."

do {
    $count = $count + 1
    try {
        Set-AzContext -Subscription $sub -ErrorAction Stop | Out-Null

        $targetVmName = "labvm-$DID"
        $vm = $null

        try {
            $vm = Get-AzVM -ResourceGroupName $rg -Name $targetVmName -ErrorAction SilentlyContinue
        }
        catch {
            $vm = $null
        }

        if (-not $vm) {
            $candidateVms = @(Get-AzVM -ErrorAction Stop | Where-Object {
                ($_.Name -eq $targetVmName) -or ($_.Tags -and $_.Tags["DeploymentID"] -eq $DID)
            })

            if ($candidateVms.Count -gt 0) {
                $vm = $candidateVms | Where-Object { $_.Name -eq $targetVmName } | Select-Object -First 1
                if (-not $vm) {
                    $vm = $candidateVms | Select-Object -First 1
                }
                $rg = $vm.ResourceGroupName
            }
        }

        if (-not $vm) {
            $lastFailure = "Lab VM '$targetVmName' was not found in subscription '$sub'. The validator cannot inspect the Exercise 3 files through Azure VM Run Command."
            $message = @{
                Status  = "Failed"
                Message = $lastFailure
            } | ConvertTo-Json
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = $message
            })
            if ($count -lt 3) { Start-Sleep -Seconds 10 }
            continue
        }

        $validationScript = @'
$ErrorActionPreference = "Stop"

$labRoot = Join-Path -Path $env:SystemDrive -ChildPath "LabFiles\SoraCampaign"
$referenceImagePath = Join-Path -Path $labRoot -ChildPath "Images\EcoBottle-Reference.png"
$evidencePath = Join-Path -Path $labRoot -ChildPath "Evidence"
$worksheetCandidates = @(
    (Join-Path -Path $labRoot -ChildPath "Campaign-Worksheet.md"),
    (Join-Path -Path $evidencePath -ChildPath "Campaign-Worksheet.md")
)

function Get-WorksheetFieldText {
    param(
        [string]$Content,
        [string[]]$Labels
    )

    $lines = $Content -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($label in $Labels) {
            $escaped = [regex]::Escape($label)
            if ($lines[$i] -match "(?i)^\s*(?:[-*]\s*)?(?:#+\s*)?(?:\*\*)?$escaped(?:\*\*)?\s*[:：]?\s*(?<value>.*)$") {
                $value = $Matches["value"].Trim()
                if ($value.Length -gt 0) {
                    return $value
                }

                $collected = New-Object System.Collections.Generic.List[string]
                for ($j = $i + 1; $j -lt [Math]::Min($i + 7, $lines.Count); $j++) {
                    $nextLine = $lines[$j].Trim()
                    if ($nextLine.Length -eq 0) {
                        continue
                    }
                    if ($nextLine -match "^\s*(?:#+\s+|[-*]\s+)?(?:\*\*)?[A-Za-z0-9 /-]{3,60}(?:\*\*)?\s*[:：]\s*$") {
                        break
                    }
                    $collected.Add($nextLine) | Out-Null
                }

                if ($collected.Count -gt 0) {
                    return ($collected -join " ").Trim()
                }
            }
        }
    }

    return ""
}

function Test-CompletedText {
    param(
        [string]$Text,
        [int]$MinimumLength = 12
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    $trimmed = $Text.Trim()
    if ($trimmed.Length -lt $MinimumLength) { return $false }
    if ($trimmed -match "(?i)^(todo|tbd|n/a|na|none|select|choose|enter|paste|replace|add notes|your rationale|one or two sentences|baseline\s*/\s*refined)") { return $false }
    if ($trimmed -match "\[\s*\]|<\s*.*\s*>") { return $false }
    return $true
}

$result = [ordered]@{
    ReferenceImagePath          = $referenceImagePath
    ReferenceImageExists        = $false
    WorksheetPath               = ""
    WorksheetExists             = $false
    ImagePromptComplete         = $false
    PreferredSelectionComplete  = $false
    RationaleComplete           = $false
    EvidenceFolderPath          = $evidencePath
    EvidenceFolderExists        = $false
    ImageVariationEvidenceFiles = @()
    MissingItems                = @()
    Valid                       = $false
}

$result.ReferenceImageExists = Test-Path -LiteralPath $referenceImagePath -PathType Leaf
$result.EvidenceFolderExists = Test-Path -LiteralPath $evidencePath -PathType Container

$worksheetPath = $worksheetCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if ($worksheetPath) {
    $result.WorksheetPath = $worksheetPath
    $result.WorksheetExists = $true
    $content = Get-Content -LiteralPath $worksheetPath -Raw
    $lowerContent = $content.ToLowerInvariant()

    $hasImagePromptSection = $lowerContent -match "image\s*[-–—]?\s*to\s*[-–—]?\s*video\s+prompt|image-guided\s+prompt|image guided\s+prompt|reference\s+prompt"
    $hasReferenceLanguage = $lowerContent -match "reference image|product anchor|reference input|image-guided|image guided"
    $hasCampaignLanguage = $lowerContent -match "ecosip|eco-friendly|reusable water bottle|sustainab"
    $hasPromptDetail = $lowerContent -match "kitchen counter|camera movement|soft morning light|vertical launch video|no people|no faces"
    $result.ImagePromptComplete = $hasImagePromptSection -and $hasReferenceLanguage -and $hasCampaignLanguage -and $hasPromptDetail

    $preferredText = Get-WorksheetFieldText -Content $content -Labels @("Preferred video", "Preferred asset", "Final preferred asset", "Final selection")
    $preferredLooksSelected = $preferredText -match "(?i)baseline|refined|structured|text prompt|image-guided|image guided|image variation|reference"
    $preferredIsNotTemplateList = $preferredText -notmatch "(?i)baseline\s*/\s*refined|baseline,\s*refined"
    $result.PreferredSelectionComplete = (Test-CompletedText -Text $preferredText -MinimumLength 8) -and $preferredLooksSelected -and $preferredIsNotTemplateList

    $rationaleText = Get-WorksheetFieldText -Content $content -Labels @("Why it best fits the campaign", "Rationale", "Why selected", "Reason for selection")
    $result.RationaleComplete = Test-CompletedText -Text $rationaleText -MinimumLength 20
}

if ($result.EvidenceFolderExists) {
    $validExtensions = @(".mp4", ".png", ".jpg", ".jpeg", ".webp", ".txt")
    $candidateFiles = @(Get-ChildItem -LiteralPath $evidencePath -File -ErrorAction SilentlyContinue | Where-Object {
        $validExtensions -contains $_.Extension.ToLowerInvariant()
    })

    $imageVariationFiles = New-Object System.Collections.Generic.List[string]
    foreach ($file in $candidateFiles) {
        $baseName = $file.BaseName.ToLowerInvariant()
        $nameIndicatesImageVariation = $baseName -match "image|variation|reference|guided|screenshot|ecosip"
        $textMentionsImageVariation = $false

        if ($file.Extension.ToLowerInvariant() -eq ".txt") {
            try {
                $textContent = (Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop).ToLowerInvariant()
                $textMentionsImageVariation = $textContent -match "image\s*[-–—]?\s*to\s*[-–—]?\s*video|reference image|image-guided|image guided|image variation"
            }
            catch {
                $textMentionsImageVariation = $false
            }
        }

        if ($nameIndicatesImageVariation -or $textMentionsImageVariation) {
            $imageVariationFiles.Add($file.Name) | Out-Null
        }
    }

    $result.ImageVariationEvidenceFiles = @($imageVariationFiles | Sort-Object -Unique)
}

if (-not $result.ReferenceImageExists) { $result.MissingItems += "Reference image was not found at the expected Images folder path." }
if (-not $result.WorksheetExists) { $result.MissingItems += "Campaign-Worksheet.md was not found in the lab root folder or Evidence folder." }
if ($result.WorksheetExists -and -not $result.ImagePromptComplete) { $result.MissingItems += "Worksheet does not contain completed image-to-video/reference prompt content with reference-image and campaign details." }
if ($result.WorksheetExists -and -not $result.PreferredSelectionComplete) { $result.MissingItems += "Worksheet does not contain a completed preferred video/final selection." }
if ($result.WorksheetExists -and -not $result.RationaleComplete) { $result.MissingItems += "Worksheet does not contain a completed rationale for the preferred video." }
if (-not $result.EvidenceFolderExists) { $result.MissingItems += "Evidence folder was not found." }
if ($result.EvidenceFolderExists -and $result.ImageVariationEvidenceFiles.Count -eq 0) { $result.MissingItems += "No image-variation evidence artifact with extension .mp4, .png, .jpg, .jpeg, .webp, or .txt was found in the Evidence folder." }

$result.Valid = $result.ReferenceImageExists -and $result.WorksheetExists -and $result.ImagePromptComplete -and $result.PreferredSelectionComplete -and $result.RationaleComplete -and $result.EvidenceFolderExists -and ($result.ImageVariationEvidenceFiles.Count -gt 0)

Write-Output "CLOUDLABS_VALIDATION_JSON_START"
Write-Output ($result | ConvertTo-Json -Depth 6 -Compress)
Write-Output "CLOUDLABS_VALIDATION_JSON_END"
'@

        $runResult = Invoke-AzVMRunCommand -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name -CommandId "RunPowerShellScript" -ScriptString $validationScript -ErrorAction Stop
        $runMessage = ($runResult.Value | ForEach-Object { $_.Message }) -join "`n"

        $match = [regex]::Match($runMessage, "(?s)CLOUDLABS_VALIDATION_JSON_START\s*(?<json>\{.*\})\s*CLOUDLABS_VALIDATION_JSON_END")
        if (-not $match.Success) {
            $trimmedRunMessage = $runMessage
            if ($trimmedRunMessage.Length -gt 1200) {
                $trimmedRunMessage = $trimmedRunMessage.Substring(0, 1200)
            }
            $lastFailure = "Run command completed on VM '$($vm.Name)' in RG '$($vm.ResourceGroupName)', but the validation result could not be parsed. Output: $trimmedRunMessage"
            $message = @{
                Status  = "Failed"
                Message = $lastFailure
            } | ConvertTo-Json
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = $message
            })
            if ($count -lt 3) { Start-Sleep -Seconds 10 }
            continue
        }

        $remoteResult = $match.Groups["json"].Value | ConvertFrom-Json
        if ($remoteResult.Valid -eq $true) {
            $found = $true
            $evidenceFiles = @($remoteResult.ImageVariationEvidenceFiles) -join ", "
            $message = @{
                Status  = "Succeeded"
                Message = "Exercise 3 evidence is complete on VM '$($vm.Name)' in RG '$($vm.ResourceGroupName)': the supplied EcoBottle reference image exists, worksheet '$($remoteResult.WorksheetPath)' includes image-to-video prompt content plus preferred selection and rationale, and image variation evidence file(s) found: $evidenceFiles."
            } | ConvertTo-Json
        }
        else {
            $missing = @($remoteResult.MissingItems) -join " "
            $lastFailure = "Exercise 3 evidence is incomplete on VM '$($vm.Name)' in RG '$($vm.ResourceGroupName)'. $missing"
            $message = @{
                Status  = "Failed"
                Message = $lastFailure
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
        $lastFailure = "Error during image variation and evaluation check. Attempt $count of 3. Error: $($_.Exception.Message)"
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
        Message = "Image variation and evaluation validation did not pass after 3 attempts. Last result: $lastFailure"
    } | ConvertTo-Json
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $message
    })
}
