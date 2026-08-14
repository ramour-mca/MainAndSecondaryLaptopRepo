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

$SoftwareNameKinect     = "KINECT CAD Integration"
[version]$KinectVersion = 27.7.7.1

$InstallMeridian        = "$PSScriptRoot\Meridian(x64).msi"  #"`"$((Get-Item -Path $PSScriptRoot\* -Include *.msi).FullName)`""
$InstallKinect          = "$PSScriptRoot\KINECT.msi"

$MeridianInstallationSwitches   = "/quiet ALLUSERS=1 REBOOT=ReallySuppress ADDLOCAL=Common,AMHook,Download,PublisherExt,Viewer,DBX,NETInterops,Acad2021,Acad2023,Acad2025,Acad2026,NETAPI,Revit,Inventor REMOVE=Acad2019,Acad2020,Acad2022,Acad2024 WEBACCESSURL=http://ibredm101/Meridian/Start SCURL=http://ibredm101/BCSiteCache"
$KinnectInstallationSwitches    = "/quiet /norestart"

$UninstallationSwitches = "/quiet /norestart"


Import-Module "$PSScriptRoot\SoftwareInstallation.psm1" -Force

$test = get-installedsoftware $Global:Softwarename

write-host $test.SoftwareName -ForegroundColor Red

if (!($Uninstall.IsPresent)) {
   
      write-host "uninstall is present" -ForegroundColor Yellow
      Write-Log "(¯`·._.·(¯`·._.· $Global:Softwarename And $SoftwareNameKinect Installation Begin ·._.·´¯)·._.·´¯)"

      if (get-installedsoftware $Global:Softwarename) {

        Uninstall-Software $Global:Softwarename -UninstallSwitches $UninstallationSwitches
      } 
      
      # Run the registry modification and wait for verification
      $regResult = Set-MeridianBCRegKey -TimeoutSec 20 -PollIntervalMs 250

      if (-not $regResult.Success) {
            Write-Log "Registry verification failed: $($regResult.Message)"
            Write-ScriptErrors $Error
            throw "Installation aborted: Registry verification failed."
      }

      Install-Software $InstallMeridian  $MeridianInstallationSwitches
      Install-Software $InstallKinect    $KinnectInstallationSwitches

      Write-Log "Tattooing registry"
      
      Set-Tattoo -Publisher $Global:Publisher -SoftwareName $Global:SoftwareName -Version $Version

      Write-Log "(¯`·._.·(¯`·._.· $Global:Softwarename Installation End ·._.·´¯)·._.·´¯)"

      Set-Tattoo -Publisher $Global:Publisher -SoftwareName $SoftwareNameKinect -Version $KinectVersion

      Write-Log "(¯`·._.·(¯`·._.· $SoftwareNameKinect Installation End ·._.·´¯)·._.·´¯)"

      Write-ScriptErrors $Error
      
      
   }

else {
      
      Write-Log "(¯`·._.·(¯`·._.· $Global:Softwarename And $SoftwareNameKinect Uninstall Script Begin ·._.·´¯)·._.·´¯)"
      
      #**********************************************************************************************
      #This line Uninstalls Meridian Enterprise (x84) with defined parameters
      Uninstall-Software $Global:Softwarename -UninstallSwitches $UninstallationSwitches
      
      #**********************************************************************************************
      #Uninstalling KINECT by changing the Softwarename variable
      Uninstall-Software $SoftwareNameKinect -UninstallationSwitches $UninstallationSwitches
      #***********************************************************************************************

      Set-Tattoo -Publisher $Global:Publisher -SoftwareName $Global:SoftwareName -Clean
      Set-Tattoo -Publisher $Global:Publisher -SoftwareName $SoftwareNameKinect  -Clean

      Write-ScriptErrors $Error
      
      Write-Log "(¯`·._.·(¯`·._.· $Global:Softwarename Uninstall Script End ·._.·´¯)·._.·´¯)"

   }
