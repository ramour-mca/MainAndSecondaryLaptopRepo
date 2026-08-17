<#
    Specify installation type
        0 = Device
        1 = User
#>
$InstallType = 0
$SoftwareName = "Meridian Enterprise (x64)"
[version]$SoftwareVersion = "9.90.69.0"
# Set Software Installed Variable to false
$SoftwareIsInstalled = $false

# Get Device Installed Software
If ($InstallType -eq 0) {

    $InstalledSoftware64 = (Get-ItemProperty HKLM:\software\wow6432node\Microsoft\Windows\CurrentVersion\Uninstall\*)
    $InstalledSoftware32 = (Get-ItemProperty HKLM:\software\Microsoft\Windows\CurrentVersion\Uninstall\*)
    $AllInstalledSoftware = ($InstalledSoftware32 + $InstalledSoftware64) | Sort-Object DisplayName
}
# Get User Installed Software
Elseif ($InstallType -eq 1) {

    $UserInstalledSoftware32 = (Get-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*)
    $AllInstalledSoftware = ($UserInstalledSoftware32) | Sort-Object DisplayName
}

# Filter Results
$SoftwareInstalls = $AllInstalledSoftware | Where-Object DisplayName -Like $SoftwareName

# Validate Version is Greater Than or Equal To Required Version
Foreach ($SoftwareInstall in $SoftwareInstalls) {

    $AppVersion = $SoftwareInstall.DisplayVersion
    If ($AppVersion.Split('.').Count -lt 4) {
        $AppVersion = Switch ($AppVersion) {
            { $PSItem.Split('.').Count -eq 1 } { "$AppVersion.0.0.0" }
            { $PSItem.Split('.').Count -eq 2 } { "$AppVersion.0.0" }
            { $PSItem.Split('.').Count -eq 3 } { "$AppVersion.0" }
        }
    }
    If ([version]$AppVersion -ge $SoftwareVersion) {

        $SoftwareIsInstalled = $true
    }
}
# Check Compliancy
If ($SoftwareIsInstalled -eq $true) {

    Write-Output "Compliant"
}else {Write-Output "not installed"}