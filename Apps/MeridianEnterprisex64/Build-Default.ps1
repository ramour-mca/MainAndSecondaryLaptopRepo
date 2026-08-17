#Requires -Version 7
[cmdletbinding()]
Param(
    [Parameter(Mandatory = $false)]
    [String]$Publisher = '',
    [Parameter(Mandatory = $false)]
    [String]$AppName = '',
    [Parameter(Mandatory=$false)]
    [String]$Description = '',
    [Parameter(Mandatory = $false)]
    [String]$Architecture = 'x64',
    [Parameter(Mandatory = $false)]
    [String]$Channel = 'Stable',
    [Parameter(Mandatory = $false)]
    [String]$Platform = 'win32-x64$',
    [Parameter(Mandatory=$false)]
    [String]$BO = 'NPS', # Bureau or Office
    [Parameter(Mandatory=$false)]
    [ValidateSet('system','user')]
    [String]$InstallType = 'system',
    [Parameter(Mandatory=$false)]
    [string[]]$Scopes = @('NPS-Windows'
                          'NPS-AK-Windows'
                          'NPS-IM-Windows'
                          'NPS-MW-Windows'
                          'NPS-NC-Windows'
                          'NPS-NE-Windows'
                          'NPS-PW-Windows'
                          'NPS-SE-Windows'
                          'NPS-WO-Windows')
)
Try {
    Import-Module MSAL.PS -ErrorAction Stop
    Import-Module IntuneWin32App -ErrorAction Stop
    Import-Module Evergreen -ErrorAction Stop
    Import-Module NPSFunctions -ErrorAction Stop
}
Catch {
    $_
    Write-Error -Message "One or more modules are missing. Please install MSAL.PS, IntuneWin32App, and Evergreen modules." -ErrorAction Stop
}
If (Test-AccessToken) {
    Write-Host "Access token valid until $($AccessToken.ExpiresOn.DateTime.ToLocalTime())" -ForegroundColor Cyan
}
Else {
    Write-Host "Access token expired. Please reconnect. Exiting." -ForegroundColor Yellow
    Return
}

$UpdateNeeded = $false
$EvergreenApps = Import-CSV $PSScriptRoot\MasterEvergreenAppList.csv
$ESearch = ($EvergreenApps | Where-Object Application -eq $AppName).Name
$developer = (Get-intuneWin32Settings).developer
$developer = $developer.Trim("@cid.doi.gov")   
$App = Get-EvergreenApp -Name $Esearch | Where-Object { $_.Architecture -match $Architecture -and $_.Platform -match $Platform -and $_.Channel -match $Channel }

$AppVersion = $App.Version
If ($AppVersion.Split('.').Count -lt 4) {
    $AppVersion = Switch ($AppVersion) {
        { $PSItem.Split('.').Count -eq 1 } { "$AppVersion.0.0.0" }
        { $PSItem.Split('.').Count -eq 2 } { "$AppVersion.0.0" }
        { $PSItem.Split('.').Count -eq 3 } { "$AppVersion.0" }
    }
}

$IntuneApp = (Get-IntuneWin32App -DisplayName "$BO-$AppName*" | Sort-Object createdDateTime)[-1]

If (-not([String]::IsNullOrEmpty($IntuneApp))) {
    If ([Version]$AppVersion -gt [Version]$IntuneApp.DisplayVersion) {
        $UpdateNeeded = $true
        "$AppVersion - $($IntuneApp.displayVersion)"
    }
}
Else {
    $UpdateNeeded = $true
}

If ($UpdateNeeded -eq $false) {
    Write-Host "Application is up to date. Exiting."
    Return
}

If (-not(Test-Path -Path "$PSScriptRoot\$Publisher\$Esearch")) {
    New-Item -Path "$PSScriptRoot\$Publisher\$Esearch" -ItemType Directory | Out-Null
    New-Item -Path "$PSScriptRoot\$Publisher\$ESearch\$Esearch.txt" -ItemType File -Value "Evergreen App. Do not delete this file." | Out-Null
    Copy-Item -Path $PSScriptRoot\zInstallWrappers\* -Exclude "Build-Default.ps1" -Destination "$PSScriptRoot\$Publisher\$ESearch" | Out-Null
    Save-EvergreenApp -InputObject $App -CustomPath "$PSScriptRoot\$Publisher\$ESearch"
    $InstallFile = Get-Content "$PSScriptRoot\$Publisher\$Esearch\Install.ps1"
    $InstallFile[24] = $InstallFile[24].Replace('PRODUCT', $ESearch)
    $InstallFile[26] = $InstallFile[26].Replace('"AUTHOR"', "`"$((whoami).split('\')[-1].ToUpper())`"")
    $InstallFile[27] = $InstallFile[27].Replace('"DATE"', "`"$(Get-Date -Format 'MM/dd/yyyy')`"")
    $InstallFile[28] = $InstallFile[28].Replace('PRODUCT', $AppName)
    $InstallFile[32] = $InstallFile[32].Replace('AppPublisher', $Publisher)
    $InstallFile[33] = $InstallFile[33].Replace('AppProduct', $AppName)
    Set-Content -Path "$PSScriptRoot\$Publisher\$Esearch\Install.ps1" -Value $InstallFile -Force
    $Detection = Get-Content "$PSScriptRoot\$Publisher\$Esearch\Detection.ps1"
    $Detection[6] = $Detection[6].Replace('PRODUCT', $AppName)
    $Detection[7] = $Detection[7].Replace('1.0.0.0', $AppVersion)
    Set-Content -Path "$PSScriptRoot\$Publisher\$Esearch\Detection.ps1" -Value $Detection -Force
    $RequirementDetection = Get-Content "$PSScriptRoot\$Publisher\$Esearch\UpdateRequirement.ps1"
    $RequirementDetection[6] = $RequirementDetection[6].Replace('PRODUCT', $AppName)
    Set-Content -Path "$PSScriptRoot\$Publisher\$Esearch\UpdateRequirement.ps1" -Value $RequirementDetection -Force
    Write-Host "Finished staging files." -ForegroundColor Cyan
    Write-Host "When downloading the icon file, ensure it is a transparent .png file and it must be named $ESearch.png" -ForegroundColor Yellow
    Write-Host "Please test and update if needed. Rerun this script when ready to create the applications"
    RETURN
}

Get-Item -Path "$PSScriptRoot\$Publisher\$Esearch\*" -Include "*.$($App.URI.Split('.')[-1])" | Remove-Item -Force
Save-EvergreenApp -InputObject $App -CustomPath "$PSScriptRoot\$Publisher\$ESearch"
$InstallFile = Get-Content "$PSScriptRoot\$Publisher\$Esearch\Install.ps1"
$InstallFile[26] = $InstallFile[26].Replace($Installfile[26].Substring(26), "`"$((whoami).split('\')[-1].ToUpper())`"")
$InstallFile[27] = $InstallFile[27].Replace($Installfile[27].Substring(26), "`"$(Get-Date -Format 'MM/dd/yyyy')`"")
Set-Content -Path "$PSScriptRoot\$Publisher\$Esearch\Install.ps1" -Value $InstallFile -Force
$Detection = Get-Content "$PSScriptRoot\$Publisher\$Esearch\Detection.ps1"
$Detection[7] = $Detection[7].Replace($Detection[7].Substring(28),"`"$AppVersion`"")
Set-Content -Path "$PSScriptRoot\$Publisher\$Esearch\Detection.ps1" -Value $Detection -Force

If(-not(Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert)){
    Write-Host "No code signing certificate found. Please request a new certificate using the DOI Code Signing template." -ForegroundColor Yellow
    RETURN
}

Publish-Signature -Path "$PSScriptRoot\$Publisher\$ESearch" -IsDirectory -Extensions ps1,psm1

&"$PSScriptRoot\ContentPrep\IntuneWinAppUtil.exe" -o "$PSScriptRoot\..\IntunewinFiles\" -c "$PSScriptRoot\$Publisher\$ESearch" -s "$PSScriptRoot\$Publisher\$ESearch\$Esearch.txt" -q

$InstallString = "Install.bat -Version $AppVersion"
$UninstallSting = "Install.bat -Uninstall"
$DetectionRule = New-IntuneWin32AppDetectionRuleScript -ScriptFile "$PSScriptRoot\$Publisher\$ESearch\Detection.ps1" -EnforceSignatureCheck $false -RunAs32Bit $false
$RequirementRule = New-IntuneWin32AppRequirementRule -Architecture x64 -MinimumSupportedWindowsRelease W11_22H2
$RequirementRuleScript = New-IntuneWin32AppRequirementRuleScript -ScriptFile "$PSScriptRoot\$Publisher\$Esearch\UpdateRequirement.ps1" -StringOutputDataType -ScriptContext system -StringValue "Compliant" -StringComparisonOperator equal -RunAs32BitOn64System $false -EnforceSignatureCheck $false
$Icon = New-IntuneWin32AppIcon -FilePath "$PSScriptRoot\_Logos\$Esearch.png"

Add-IntuneWin32App -FilePath "$PSScriptRoot\..\IntunewinFiles\$ESearch.intunewin" `
    -DisplayName "$BO-$AppName" -Description $Description -Publisher $Publisher -AppVersion $AppVersion -Developer "$BO Evergreen" `
    -Owner $BO -InstallCommandLine $InstallString -UninstallCommandLine $UninstallSting -InstallExperience $InstallType -RestartBehavior allow `
    -AllowAvailableUninstall -DetectionRule $DetectionRule -RequirementRule $RequirementRule -Icon $Icon -ScopeTagName $Scopes

Add-IntuneWin32App -FilePath "$PSScriptRoot\..\IntunewinFiles\$ESearch.intunewin" `
    -DisplayName "$BO-$AppName (Update)" -Description $Description -Publisher $Publisher -AppVersion $AppVersion -Developer "$BO Evergreen" `
    -Owner $BO -InstallCommandLine $InstallString -UninstallCommandLine $UninstallSting -InstallExperience $InstallType -RestartBehavior allow `
    -AllowAvailableUninstall -DetectionRule $DetectionRule -RequirementRule $RequirementRule -Icon $Icon -ScopeTagName $Scopes `
    -AdditionalRequirementRule $RequirementRuleScript