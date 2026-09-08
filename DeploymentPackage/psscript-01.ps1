Param(
    [string] $AzureUserName,
    [string] $AzurePassword,
    [string] $AzureTenantID,
    [string] $AzureSubscriptionID,
    [string] $ODLID,
    [string] $InstallCloudLabsShadow = "true",
    [string] $DeploymentID,
    [string] $vmAdminUsername,
    [string] $vmAdminPassword,
    [string] $trainerUserName,
    [string] $trainerUserPassword
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

New-Item -ItemType Directory -Path "C:\WindowsAzure\Logs" -Force | Out-Null
Start-Transcript -Path "C:\WindowsAzure\Logs\CloudLabsCustomScriptExtension.txt" -Append

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Log {
    param([string] $Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

function Invoke-WithRetry {
    param(
        [scriptblock] $ScriptBlock,
        [int] $MaxAttempts = 3,
        [int] $DelaySeconds = 10,
        [string] $OperationName = "operation"
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Write-Log "Starting $OperationName (attempt $attempt of $MaxAttempts)."
            $result = & $ScriptBlock
            return $result
        }
        catch {
            Write-Log "$OperationName failed on attempt $attempt. $($_.Exception.Message)"
            if ($attempt -lt $MaxAttempts) {
                Start-Sleep -Seconds $DelaySeconds
            }
            else {
                throw
            }
        }
    }
}

function CreateCredFile {
    param(
        [string] $LabFilesRoot = "C:\LabFiles"
    )

    Write-Log "Creating CloudLabs credential helper files."
    New-Item -ItemType Directory -Path $LabFilesRoot -Force | Out-Null
    New-Item -ItemType Directory -Path "C:\Users\Public\Desktop" -Force | Out-Null

    $commonBaseUrl = "https://experienceazure.blob.core.windows.net/templates/cloudlabs-common"
    $downloadTargets = @(
        @{ Name = "AzureCreds.txt"; Path = (Join-Path $LabFilesRoot "AzureCreds.txt") },
        @{ Name = "AzureCreds.ps1"; Path = (Join-Path $LabFilesRoot "AzureCreds.ps1") }
    )

    foreach ($target in $downloadTargets) {
        $uri = "$commonBaseUrl/$($target.Name)"
        try {
            Invoke-WebRequest -Uri $uri -OutFile $target.Path -UseBasicParsing -ErrorAction Stop
            Write-Log "Downloaded $($target.Name) from CloudLabs common helpers."
        }
        catch {
            Write-Log "Unable to download $($target.Name); creating local fallback. $($_.Exception.Message)"
            if ($target.Name -eq "AzureCreds.txt") {
                @"
Azure portal credentials

Username: <AzureUserName>
Password: <AzurePassword>
Tenant ID: <AzureTenantID>
Subscription ID: <AzureSubscriptionID>
Foundry portal: https://ai.azure.com
"@ | Set-Content -Path $target.Path -Encoding UTF8
            }
            else {
                @"
`$AzureUserName = '<AzureUserName>'
`$AzurePassword = '<AzurePassword>'
`$AzureTenantID = '<AzureTenantID>'
`$AzureSubscriptionID = '<AzureSubscriptionID>'
"@ | Set-Content -Path $target.Path -Encoding UTF8
            }
        }

        $content = Get-Content -Path $target.Path -Raw
        $content = $content.Replace("<AzureUserName>", $AzureUserName)
        $content = $content.Replace("<AzurePassword>", $AzurePassword)
        $content = $content.Replace("<AzureTenantID>", $AzureTenantID)
        $content = $content.Replace("<AzureSubscriptionID>", $AzureSubscriptionID)
        $content = $content.Replace("AzureUserNameValue", $AzureUserName)
        $content = $content.Replace("AzurePasswordValue", $AzurePassword)
        $content = $content.Replace("AzureTenantIDValue", $AzureTenantID)
        $content = $content.Replace("AzureSubscriptionIDValue", $AzureSubscriptionID)
        $content = $content.Replace("GET-AZUSER-UPN", $AzureUserName)
        $content = $content.Replace("GET-AZUSER-PASSWORD", $AzurePassword)
        $content = $content.Replace("GET-AZURE-TENANT-ID", $AzureTenantID)
        $content = $content.Replace("GET-AZURE-SUBSCRIPTION-ID", $AzureSubscriptionID)
        Set-Content -Path $target.Path -Value $content -Encoding UTF8

        Copy-Item -Path $target.Path -Destination (Join-Path "C:\Users\Public\Desktop" $target.Name) -Force
    }
}

function Enable-TrainerShadowAccount {
    $shadowRequested = $true
    if (-not [string]::IsNullOrWhiteSpace($InstallCloudLabsShadow)) {
        $shadowRequested = ($InstallCloudLabsShadow.ToString().Trim().ToLowerInvariant() -notin @("false", "0", "no"))
    }

    if (-not $shadowRequested) {
        Write-Log "InstallCloudLabsShadow was explicitly disabled. Skipping trainer local account creation."
        return
    }

    if ([string]::IsNullOrWhiteSpace($trainerUserName) -or [string]::IsNullOrWhiteSpace($trainerUserPassword)) {
        Write-Log "Trainer user name or password was not supplied. Skipping trainer local account creation."
        return
    }

    try {
        Write-Log "Creating or updating local trainer account for VM Shadow: $trainerUserName."
        $securePassword = ConvertTo-SecureString $trainerUserPassword -AsPlainText -Force
        $existingUser = Get-LocalUser -Name $trainerUserName -ErrorAction SilentlyContinue
        if ($null -eq $existingUser) {
            New-LocalUser -Name $trainerUserName -Password $securePassword -PasswordNeverExpires -UserMayNotChangePassword -FullName "CloudLabs Instructor" -Description "CloudLabs VM Shadow instructor account" | Out-Null
        }
        else {
            Set-LocalUser -Name $trainerUserName -Password $securePassword -PasswordNeverExpires $true
            Enable-LocalUser -Name $trainerUserName
        }

        foreach ($groupName in @("Remote Desktop Users", "Administrators")) {
            try {
                Add-LocalGroupMember -Group $groupName -Member $trainerUserName -ErrorAction Stop
                Write-Log "Added $trainerUserName to local group '$groupName'."
            }
            catch {
                if ($_.Exception.Message -match "already") {
                    Write-Log "$trainerUserName is already a member of '$groupName'."
                }
                else {
                    Write-Log "Unable to add $trainerUserName to '$groupName'. $($_.Exception.Message)"
                }
            }
        }
    }
    catch {
        Write-Log "Trainer account setup failed. $($_.Exception.Message)"
    }
}

function Ensure-AzureCli {
    $azCommand = Get-Command az -ErrorAction SilentlyContinue
    if ($null -ne $azCommand) {
        Write-Log "Azure CLI is already installed at $($azCommand.Source)."
        return
    }

    Write-Log "Azure CLI not found. Installing Azure CLI MSI."
    $installerPath = "C:\Windows\Temp\AzureCLI.msi"
    Invoke-WithRetry -OperationName "download Azure CLI MSI" -ScriptBlock {
        Invoke-WebRequest -Uri "https://aka.ms/installazurecliwindows" -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
    }
    Start-Process msiexec.exe -Wait -ArgumentList "/I `"$installerPath`" /quiet"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Get-AzureMetadataResourceGroup {
    try {
        $metadata = Invoke-RestMethod -Headers @{ Metadata = "true" } -Method GET -Uri "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01" -TimeoutSec 10
        return $metadata.resourceGroupName
    }
    catch {
        Write-Log "Could not read resource group from Azure Instance Metadata Service. $($_.Exception.Message)"
        return $null
    }
}

function Connect-AzureForSetup {
    Ensure-AzureCli

    if ([string]::IsNullOrWhiteSpace($AzureUserName) -or [string]::IsNullOrWhiteSpace($AzurePassword) -or [string]::IsNullOrWhiteSpace($AzureTenantID)) {
        Write-Log "Azure credentials were not supplied to the CSE. Skipping Azure CLI sign-in."
        return $false
    }

    try {
        Write-Log "Signing in to Azure CLI as lab user $AzureUserName."
        az cloud set --name AzureCloud | Out-Null
        az login --service-principal --username $AzureUserName --password $AzurePassword --tenant $AzureTenantID --allow-no-subscriptions 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Service principal style sign-in did not succeed; trying user credential sign-in."
            az login --username $AzureUserName --password $AzurePassword --tenant $AzureTenantID --allow-no-subscriptions 2>$null | Out-Null
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Azure CLI sign-in failed. Continuing with locally derived deployment information."
            return $false
        }
        if (-not [string]::IsNullOrWhiteSpace($AzureSubscriptionID)) {
            az account set --subscription $AzureSubscriptionID | Out-Null
        }
        return $true
    }
    catch {
        Write-Log "Azure CLI sign-in failed. $($_.Exception.Message)"
        return $false
    }
}

function Resolve-FoundryDeploymentInfo {
    param([bool] $AzureCliSignedIn)

    $resourceGroupName = Get-AzureMetadataResourceGroup
    if ([string]::IsNullOrWhiteSpace($resourceGroupName) -and $AzureCliSignedIn) {
        try {
            $resourceGroupName = az group list --query "[?tags.DeploymentID=='$DeploymentID'].name | [0]" -o tsv
        }
        catch {
            Write-Log "Resource group lookup by tag failed. $($_.Exception.Message)"
        }
    }

    $foundryResourceName = $null
    $foundryProjectName = $null
    $foundryResourceEndpoint = $null
    $openAIEndpoint = $null
    $foundryLocation = $null
    $apiKey = $null

    if ($AzureCliSignedIn -and -not [string]::IsNullOrWhiteSpace($resourceGroupName)) {
        try {
            $foundryResourceName = az cognitiveservices account list --resource-group $resourceGroupName --query "[?tags.Lab=='Sora2Campaign' && tags.DeploymentID=='$DeploymentID'].name | [0]" -o tsv
            if ([string]::IsNullOrWhiteSpace($foundryResourceName)) {
                $foundryResourceName = az cognitiveservices account list --resource-group $resourceGroupName --query "[?kind=='AIServices'].name | [0]" -o tsv
            }
            if (-not [string]::IsNullOrWhiteSpace($foundryResourceName)) {
                $accountJson = az cognitiveservices account show --resource-group $resourceGroupName --name $foundryResourceName -o json | ConvertFrom-Json
                $foundryResourceEndpoint = $accountJson.properties.endpoint
                $foundryLocation = $accountJson.location
                $openAIEndpoint = "https://$foundryResourceName.openai.azure.com/"
                $apiKey = az cognitiveservices account keys list --resource-group $resourceGroupName --name $foundryResourceName --query "key1" -o tsv
            }
        }
        catch {
            Write-Log "Foundry resource lookup failed. $($_.Exception.Message)"
        }

        try {
            if (-not [string]::IsNullOrWhiteSpace($foundryResourceName)) {
                $foundryProjectName = az rest --method get --url "https://management.azure.com/subscriptions/$AzureSubscriptionID/resourceGroups/$resourceGroupName/providers/Microsoft.CognitiveServices/accounts/$foundryResourceName/projects?api-version=2025-06-01" --query "value[?tags.Lab=='Sora2Campaign'].name | [0]" -o tsv 2>$null
            }
        }
        catch {
            Write-Log "Foundry project lookup failed. $($_.Exception.Message)"
        }
    }

    if ([string]::IsNullOrWhiteSpace($foundryResourceName) -and -not [string]::IsNullOrWhiteSpace($resourceGroupName)) {
        Write-Log "Using deployment-info fallback values because live Foundry lookup did not return a resource."
    }

    if ([string]::IsNullOrWhiteSpace($foundryResourceEndpoint) -and -not [string]::IsNullOrWhiteSpace($foundryResourceName)) {
        $foundryResourceEndpoint = "https://$foundryResourceName.cognitiveservices.azure.com/"
    }
    if ([string]::IsNullOrWhiteSpace($openAIEndpoint) -and -not [string]::IsNullOrWhiteSpace($foundryResourceName)) {
        $openAIEndpoint = "https://$foundryResourceName.openai.azure.com/"
    }

    [pscustomobject]@{
        ResourceGroupName          = $resourceGroupName
        SubscriptionId             = $AzureSubscriptionID
        TenantId                   = $AzureTenantID
        FoundryResourceName        = $foundryResourceName
        FoundryProjectName         = $foundryProjectName
        FoundryResourceEndpoint    = $foundryResourceEndpoint
        OpenAIEndpoint             = $openAIEndpoint
        FoundryLocation            = $foundryLocation
        ExpectedSoraDeploymentName = "sora2-campaign"
        SoraModelName              = "sora-2"
        FoundryPortalUrl           = "https://ai.azure.com"
        LabFilesPath               = "C:\LabFiles\SoraCampaign"
        AzureOpenAIKey             = $apiKey
    }
}

function New-EcoBottleReferenceImage {
    param([string] $ImagePath)

    Write-Log "Creating rights-cleared no-face product reference image at $ImagePath."
    Add-Type -AssemblyName System.Drawing

    $width = 720
    $height = 1280
    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle 0, 0, $width, $height),
        [System.Drawing.Color]::FromArgb(245, 252, 246),
        [System.Drawing.Color]::FromArgb(207, 235, 217),
        [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
    $graphics.FillRectangle($bgBrush, 0, 0, $width, $height)

    $tableBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(196, 164, 112))
    $graphics.FillRectangle($tableBrush, 0, 940, $width, 340)

    $shadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(60, 70, 90, 70))
    $graphics.FillEllipse($shadowBrush, 220, 980, 280, 48)

    $bottleBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle 250, 310, 220, 700),
        [System.Drawing.Color]::FromArgb(51, 117, 78),
        [System.Drawing.Color]::FromArgb(119, 176, 119),
        [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
    )
    $outlinePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(29, 84, 56)), 5
    $highlightBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90, 255, 255, 255))

    $bodyRect = New-Object System.Drawing.Rectangle 250, 395, 220, 590
    $graphics.FillRectangle($bottleBrush, $bodyRect)
    $graphics.DrawRectangle($outlinePen, $bodyRect)
    $graphics.FillEllipse($bottleBrush, 250, 355, 220, 90)
    $graphics.DrawEllipse($outlinePen, 250, 355, 220, 90)
    $graphics.FillRectangle($bottleBrush, 300, 300, 120, 105)
    $graphics.DrawRectangle($outlinePen, 300, 300, 120, 105)
    $capBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(38, 91, 63))
    $graphics.FillRectangle($capBrush, 285, 250, 150, 60)
    $graphics.DrawRectangle($outlinePen, 285, 250, 150, 60)
    $graphics.FillRectangle($highlightBrush, 285, 430, 30, 500)

    $labelBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 248, 234))
    $labelPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(93, 138, 93)), 3
    $graphics.FillRectangle($labelBrush, 275, 625, 170, 125)
    $graphics.DrawRectangle($labelPen, 275, 625, 170, 125)

    $fontTitle = New-Object System.Drawing.Font "Segoe UI", 30, ([System.Drawing.FontStyle]::Bold)
    $fontSmall = New-Object System.Drawing.Font "Segoe UI", 16, ([System.Drawing.FontStyle]::Regular)
    $textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(38, 91, 63))
    $graphics.DrawString("EcoSip", $fontTitle, $textBrush, 300, 645)
    $graphics.DrawString("Reusable", $fontSmall, $textBrush, 311, 700)

    $plantPotBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(158, 103, 62))
    $leafBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(72, 145, 85))
    $graphics.FillRectangle($plantPotBrush, 88, 835, 105, 120)
    $graphics.FillEllipse($leafBrush, 76, 740, 70, 130)
    $graphics.FillEllipse($leafBrush, 130, 720, 80, 150)
    $graphics.FillEllipse($leafBrush, 174, 760, 70, 120)

    $badgeBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 255, 235))
    $graphics.FillEllipse($badgeBrush, 482, 145, 150, 150)
    $graphics.DrawString("No faces`nNo logos", $fontSmall, $textBrush, 511, 190)

    $subtitleFont = New-Object System.Drawing.Font "Segoe UI", 18, ([System.Drawing.FontStyle]::Regular)
    $graphics.DrawString("Rights-cleared lab reference image", $subtitleFont, $textBrush, 175, 1090)

    $bitmap.Save($ImagePath, [System.Drawing.Imaging.ImageFormat]::Png)

    $graphics.Dispose()
    $bitmap.Dispose()
    $bgBrush.Dispose()
    $tableBrush.Dispose()
    $shadowBrush.Dispose()
    $bottleBrush.Dispose()
    $outlinePen.Dispose()
    $highlightBrush.Dispose()
    $capBrush.Dispose()
    $labelBrush.Dispose()
    $labelPen.Dispose()
    $fontTitle.Dispose()
    $fontSmall.Dispose()
    $textBrush.Dispose()
    $plantPotBrush.Dispose()
    $leafBrush.Dispose()
    $badgeBrush.Dispose()
    $subtitleFont.Dispose()
}

function New-LabFiles {
    param([object] $Info)

    $labRoot = "C:\LabFiles\SoraCampaign"
    $imagesPath = Join-Path $labRoot "Images"
    $evidencePath = Join-Path $labRoot "Evidence"

    New-Item -ItemType Directory -Path $labRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $imagesPath -Force | Out-Null
    New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null

    $imagePath = Join-Path $imagesPath "EcoBottle-Reference.png"
    if (-not (Test-Path $imagePath)) {
        try {
            New-EcoBottleReferenceImage -ImagePath $imagePath
        }
        catch {
            Write-Log "PNG generation failed; writing safe SVG fallback next to expected image path. $($_.Exception.Message)"
            $svgPath = Join-Path $imagesPath "EcoBottle-Reference.svg"
            @"
<svg xmlns="http://www.w3.org/2000/svg" width="720" height="1280" viewBox="0 0 720 1280">
  <rect width="720" height="1280" fill="#eef8ef"/>
  <rect y="940" width="720" height="340" fill="#c4a470"/>
  <ellipse cx="360" cy="1004" rx="150" ry="28" fill="#586b46" opacity="0.35"/>
  <rect x="250" y="390" width="220" height="595" rx="36" fill="#4f9a62" stroke="#1d5438" stroke-width="6"/>
  <rect x="300" y="300" width="120" height="110" fill="#4f9a62" stroke="#1d5438" stroke-width="6"/>
  <rect x="285" y="250" width="150" height="60" fill="#265b3f" stroke="#1d5438" stroke-width="6"/>
  <rect x="275" y="625" width="170" height="125" fill="#ebf8ea" stroke="#5d8a5d" stroke-width="4"/>
  <text x="300" y="690" font-family="Segoe UI, Arial" font-size="42" font-weight="700" fill="#265b3f">EcoSip</text>
  <text x="300" y="728" font-family="Segoe UI, Arial" font-size="24" fill="#265b3f">Reusable</text>
  <text x="150" y="1105" font-family="Segoe UI, Arial" font-size="28" fill="#265b3f">Rights-cleared lab reference image - no faces</text>
</svg>
"@ | Set-Content -Path $svgPath -Encoding UTF8
        }
    }

    $worksheetPath = Join-Path $labRoot "Campaign-Worksheet.md"
    if (-not (Test-Path $worksheetPath)) {
        @"
# Sora 2 EcoSip Campaign Worksheet

Use this worksheet to record prompts, observations, evidence file names, and your final campaign selection.

## Lab deployment details

- Foundry portal: $($Info.FoundryPortalUrl)
- Resource group: $($Info.ResourceGroupName)
- Foundry / Azure AI resource: $($Info.FoundryResourceName)
- Foundry project: $($Info.FoundryProjectName)
- Sora deployment name: $($Info.ExpectedSoraDeploymentName)
- Model name: $($Info.SoraModelName)
- Reference image: C:\LabFiles\SoraCampaign\Images\EcoBottle-Reference.png
- Evidence folder: C:\LabFiles\SoraCampaign\Evidence

## Exercise 1 - Deployment confirmation

- Deployment visible in Foundry: Yes / No
- Video playground opened: Yes / No
- Notes:

## Exercise 2 - Baseline text-to-video prompt

```text
Make a short promotional video for an eco-friendly reusable water bottle.
```

- Output file or screenshot saved in Evidence folder:
- Observations on visual quality:
- Observations on prompt adherence:
- What was missing or unclear:

## Exercise 2 - Refined structured prompt

```text
Create a 4-second vertical promotional video for an eco-friendly reusable water bottle called EcoSip. Show a sleek matte-green bottle standing on a wooden cafe table beside a small plant. Morning sunlight comes through a window, with soft natural shadows and a clean sustainable lifestyle mood. Start with a close-up of condensation on the bottle, then use a slow camera push-in as the bottle remains centered. Modern minimal product-ad style, realistic lighting, no people, no logos, no copyrighted music, suitable for all audiences.
```

- Output file or screenshot saved in Evidence folder:
- Observations on visual quality:
- Observations on prompt adherence:
- Improvement compared with the baseline:

## Exercise 3 - Image-to-video prompt

```text
Use the reference image as the product anchor. Create a 4-second vertical launch video for EcoSip, an eco-friendly reusable water bottle. Keep the bottle shape, color, and overall product identity consistent with the reference image. Place it on a bright kitchen counter with herbs, a reusable shopping bag, and soft morning light. Add gentle camera movement from left to right, shallow depth of field, clean sustainable lifestyle aesthetic, realistic product advertising style, no people, no faces, no trademarks, no copyrighted music, suitable for all audiences.
```

- Output file or screenshot saved in Evidence folder:
- Product consistency with the reference image:
- Notes about image upload or generation warnings:

## Campaign evaluation scorecard

Score each asset from 1 (low) to 5 (high).

| Criteria | Baseline | Refined text prompt | Image-guided variation |
|---|---:|---:|---:|
| Visual quality |  |  |  |
| Prompt adherence |  |  |  |
| Product/brand consistency |  |  |  |
| Camera movement and pacing |  |  |  |
| Sustainability campaign fit |  |  |  |
| Short social ad suitability |  |  |  |
| Responsible AI/content safety fit |  |  |  |

## Final preferred asset

- Preferred video: Baseline / Refined text prompt / Image-guided variation
- Why this is the best campaign asset:
- One change before production use:
"@ | Set-Content -Path $worksheetPath -Encoding UTF8
    }

    $deploymentInfoPath = Join-Path $labRoot "deployment-info.json"
    $Info | Select-Object ResourceGroupName, SubscriptionId, TenantId, FoundryResourceName, FoundryProjectName, FoundryResourceEndpoint, OpenAIEndpoint, FoundryLocation, ExpectedSoraDeploymentName, SoraModelName, FoundryPortalUrl, LabFilesPath | ConvertTo-Json -Depth 5 | Set-Content -Path $deploymentInfoPath -Encoding UTF8

    $envPath = Join-Path $labRoot ".env"
    @"
AZURE_SUBSCRIPTION_ID=$($Info.SubscriptionId)
AZURE_TENANT_ID=$($Info.TenantId)
AZURE_RESOURCE_GROUP=$($Info.ResourceGroupName)
AZURE_OPENAI_RESOURCE=$($Info.FoundryResourceName)
AZURE_FOUNDRY_RESOURCE=$($Info.FoundryResourceName)
AZURE_FOUNDRY_PROJECT=$($Info.FoundryProjectName)
AZURE_FOUNDRY_ENDPOINT=$($Info.FoundryResourceEndpoint)
AZURE_OPENAI_ENDPOINT=$($Info.OpenAIEndpoint)
AZURE_OPENAI_API_KEY=$($Info.AzureOpenAIKey)
AZURE_OPENAI_DEPLOYMENT=$($Info.ExpectedSoraDeploymentName)
SORA_DEPLOYMENT_NAME=$($Info.ExpectedSoraDeploymentName)
SORA_MODEL_NAME=$($Info.SoraModelName)
FOUNDRY_PORTAL_URL=$($Info.FoundryPortalUrl)
LABFILES_PATH=$($Info.LabFilesPath)
REFERENCE_IMAGE_PATH=C:\LabFiles\SoraCampaign\Images\EcoBottle-Reference.png
EVIDENCE_PATH=C:\LabFiles\SoraCampaign\Evidence
"@ | Set-Content -Path $envPath -Encoding UTF8

    $evidenceReadme = Join-Path $evidencePath "README.txt"
    if (-not (Test-Path $evidenceReadme)) {
        @"
Save downloaded Sora 2 videos, screenshots, and completed worksheet evidence in this folder.
Generated videos in the Microsoft Foundry Video playground are retained for a limited time, so download or capture evidence before ending the lab.
"@ | Set-Content -Path $evidenceReadme -Encoding UTF8
    }

    Copy-Item -Path $worksheetPath -Destination (Join-Path $evidencePath "Campaign-Worksheet.md") -Force
}

function New-DesktopEntryPoints {
    param([object] $Info)

    $desktop = "C:\Users\Public\Desktop"
    New-Item -ItemType Directory -Path $desktop -Force | Out-Null

    $readmePath = Join-Path $desktop "Sora Campaign Lab README.txt"
    @"
Generate AI Video Campaigns with Sora 2 in Microsoft Foundry

Start here:
1. Open Microsoft Foundry: $($Info.FoundryPortalUrl)
2. Sign in with the Azure credentials provided for this lab.
3. Select the subscription and project/resource shown below.
4. Open the Sora deployment '$($Info.ExpectedSoraDeploymentName)' in the Video playground.

Deployment details:
- Subscription ID: $($Info.SubscriptionId)
- Resource group: $($Info.ResourceGroupName)
- Foundry / Azure AI resource: $($Info.FoundryResourceName)
- Foundry project: $($Info.FoundryProjectName)
- Azure OpenAI endpoint: $($Info.OpenAIEndpoint)
- Sora model: $($Info.SoraModelName)
- Sora deployment: $($Info.ExpectedSoraDeploymentName)

Lab files:
- Root: C:\LabFiles\SoraCampaign
- Reference image: C:\LabFiles\SoraCampaign\Images\EcoBottle-Reference.png
- Evidence folder: C:\LabFiles\SoraCampaign\Evidence
- Worksheet: C:\LabFiles\SoraCampaign\Campaign-Worksheet.md

Responsible AI reminders:
- Use only rights-cleared assets.
- Avoid people, faces, public figures, copyrighted characters, copyrighted music, trademarks, and unsafe content.
- If a prompt or image is rejected, revise toward neutral product, setting, camera, lighting, and motion details.
"@ | Set-Content -Path $readmePath -Encoding UTF8

    $urlShortcut = Join-Path $desktop "Microsoft Foundry.url"
    @"
[InternetShortcut]
URL=$($Info.FoundryPortalUrl)
IconFile=C:\Windows\System32\shell32.dll
IconIndex=220
"@ | Set-Content -Path $urlShortcut -Encoding ASCII

    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut((Join-Path $desktop "Microsoft Foundry.lnk"))
        $shortcut.TargetPath = $Info.FoundryPortalUrl
        $shortcut.Description = "Open Microsoft Foundry portal for the Sora 2 campaign lab"
        $shortcut.Save()
    }
    catch {
        Write-Log "Could not create .lnk shortcut. The .url shortcut is available. $($_.Exception.Message)"
    }

    try {
        $shell = New-Object -ComObject WScript.Shell
        $folderShortcut = $shell.CreateShortcut((Join-Path $desktop "Sora Campaign Lab Files.lnk"))
        $folderShortcut.TargetPath = "C:\LabFiles\SoraCampaign"
        $folderShortcut.Description = "Open Sora Campaign lab files"
        $folderShortcut.Save()
    }
    catch {
        Write-Log "Could not create lab files folder shortcut. $($_.Exception.Message)"
    }
}

try {
    Write-Log "CloudLabs bootstrap starting for DeploymentID '$DeploymentID'."

    CreateCredFile -LabFilesRoot "C:\LabFiles"
    Enable-TrainerShadowAccount

    $signedIn = Connect-AzureForSetup
    $info = Resolve-FoundryDeploymentInfo -AzureCliSignedIn $signedIn

    Write-Log "Resolved resource group: $($info.ResourceGroupName)"
    Write-Log "Resolved Foundry resource: $($info.FoundryResourceName)"
    Write-Log "Resolved Foundry endpoint: $($info.FoundryResourceEndpoint)"
    Write-Log "Expected Sora deployment: $($info.ExpectedSoraDeploymentName). The ARM template provisions this deployment; CSE will not create or modify it."

    New-LabFiles -Info $info
    New-DesktopEntryPoints -Info $info

    Write-Log "Bootstrap completed. Lab files are available at C:\LabFiles\SoraCampaign."
}
catch {
    Write-Log "Bootstrap encountered an unrecoverable error: $($_.Exception.Message)"
    Write-Log $_.ScriptStackTrace
}
finally {
    try {
        Stop-Transcript | Out-Null
    }
    catch { }
}
