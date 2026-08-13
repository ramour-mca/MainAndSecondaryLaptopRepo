<#
.Synopsis
   Installs / Uninstalls Meridian Enterprise (x64)
.DESCRIPTION
   This script will uninstall the currently installed Meridian Enterprise (x64) and install the latest version. Using the -Uninstall parameter SOFTWARE will be uninstalled only.
.EXAMPLE
   Install.ps1
   Uninstalls Meridian Enterprise (x64) and Installs latest version on the local machine.
.EXAMPLE
   Install.ps1 -uninstall
   Uninstalls Meridian Enterprise (x64) on the local machine
.INPUTS
   -Uninstall (Uninstall Switch)
.OUTPUTS
   Log will be output to C:\SoftwareInstallations\Meridian Enterprise (x64)-Install.log
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [switch]$Uninstall,
    [Parameter(Mandatory=$false)]
    [String]$Version
)

$ScriptName             = "Install-Meridian Enterprise (x64)"
$ScriptVersion          = "1"
$ScriptAuthor           = "ramour-mca"
$ScriptLastUpdated      = "07/27/2026"
$ScriptPurpose          = "Uninstall existing versions of Meridian Enterprise (x64) and install current version."
$ErrorActionPreference  = "SilentlyContinue"

# Configure the variables required for this script
$Global:Publisher       = "Accruent"
$Global:Softwarename    = "Meridian Enterprise (x64)"
$MainVersion            = $Version
$Meridian               = "$PSScriptRoot\Meridian(x64).msi"  #"`"$((Get-Item -Path $PSScriptRoot\* -Include *.msi).FullName)`""
$Kinect                 = "$PSScriptRoot\KINECT.msi"

# *** UPDATED SWITCHES HERE ***
$MeridianInstallationSwitches   = "/quiet ALLUSERS=1 REBOOT=ReallySuppress ADDLOCAL=Common,AMHook,Download,PublisherExt,Viewer,DBX,NETInterops,Acad2021,Acad2023,Acad2025,Acad2026,NETAPI,Revit,Inventor REMOVE=Acad2019,Acad2020,Acad2022,Acad2024 WEBACCESSURL=http://ibredm101/Meridian/Start SCURL=http://ibredm101/BCSiteCache"
$KinnectInstallationSwitches    = "/quiet /norestart"

$UninstallationSwitches = "/quiet /norestart"
# ******************************


Import-Module "$PSScriptRoot\SoftwareInstallation.psm1" -Force

$test = get-installedsoftware $Global:Softwarename

write-host $test.SoftwareName -ForegroundColor Red

if (!($Uninstall.IsPresent)) {
   
      write-host "uninstall is present" -ForegroundColor Yellow
      Write-Log "(¯`·._.·(¯`·._.· $Global:Softwarename Installation Begin ·._.·´¯)·._.·´¯)"

      if (get-installedsoftware $Global:Softwarename) {

         Write-Host "stepping in function " -ForegroundColor Red
         
            Uninstall-Software $Global:Softwarename -UninstallSwitches $UninstallationSwitches
      } else {Write-host "false" -ForegroundColor yellow}

      # Run the registry modification and wait for verification
      $regResult = Set-MeridianBCRegKey -TimeoutSec 20 -PollIntervalMs 250

      if (-not $regResult.Success) {
            Write-Log "Registry verification failed: $($regResult.Message)"
            Write-ScriptErrors $Error
            throw "Installation aborted: Registry verification failed."
      }

      Install-Software $Meridian $MeridianInstallationSwitches
      Install-Software $Kinect $KinnectInstallationSwitches

      Write-Log "Tattooing registry"
      Set-Tattoo -Publisher $Global:Publisher -SoftwareName $Global:SoftwareName -Version $Version
      Write-ScriptErrors $Error
      Write-Log "(¯`·._.·(¯`·._.· $Global:Softwarename Installation End ·._.·´¯)·._.·´¯)"

else {
      Write-Log "(¯`·._.·(¯`·._.· $Global:Softwarename Uninstall Script Begin ·._.·´¯)·._.·´¯)"
      Uninstall-Software $Global:Softwarename -UninstallSwitches $UninstallationSwitches
      Set-Tattoo -Publisher $Global:Publisher -SoftwareName $Global:SoftwareName -Clean
      Write-ScriptErrors $Error
      Write-Log "(¯`·._.·(¯`·._.· $Global:Softwarename Uninstall Script End ·._.·´¯)·._.·´¯)"

   }
}