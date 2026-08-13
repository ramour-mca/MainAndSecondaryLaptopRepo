@{
    ModuleVersion = '25.6.11.0'
}

$script:quote = [char]34
$script:LogFolderName = "C:\SoftwareLogs"
$name = $global:SoftwareName -replace '\W', ''
$script:LogPath = "$LogFolderName\$Name-Install.log"

# Create the Log folder if it does not exist
If (!(Test-Path -Path "$LogFolderName")) { New-Item -ItemType directory -Path "$LogFolderName" }

#region Common Functions
Function Write-Log {
    Param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
        [AllowEmptyString()]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [string]$path = $script:LogPath,
        [Parameter(Mandatory = $false)]
        [string]$ArchivePath = $script:LogArchive,
        [Parameter(Mandatory = $false)]
        [string]$Component = $script:LogComponent,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 3)] # 1=Informational, 2=Warning, 3=Error
        [string]$Severity = 1,
        [Parameter(Mandatory = $false)]
        $MaxSize = 5MB
    )
    Begin {
        function Get-Encoding {
            Param(

                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
                [Alias('FullName')]
                [string]$Path
            )
            
            Process {

                $bom = New-Object -TypeName System.Byte[](4)
                $file = New-Object System.IO.FileStream($Path, 'Open', 'Read')
                $null = $file.Read($bom, 0, 4)
                $file.Close()
                $file.Dispose()
                $enc = "ASCII"
                if ($bom[0] -eq 0x2b -and $bom[1] -eq 0x2f -and $bom[2] -eq 0x76) {
                    $enc = "UTF7"
                }
                if ($bom[0] -eq 0xff -and $bom[1] -eq 0xfe) {
                    $enc = "Unicode"
                }
                if ($bom[0] -eq 0xfe -and $bom[1] -eq 0xff) {
                    $enc = "BigEndianUnicode"
                }
                if ($bom[0] -eq 0x00 -and $bom[1] -eq 0x00 -and $bom[2] -eq 0xfe -and $bom[3] -eq 0xff) {
                    $enc = "UTF32"
                }
                if ($bom[0] -eq 0xef -and $bom[1] -eq 0xbb -and $bom[2] -eq 0xbf) {
                    $enc = "UTF8"
                }
                        
                [PSCustomObject]@{
                    Encoding = $enc
                    Path     = $Path
                }
            }
        }
    
        if (Test-Path "$path") {
            if ((Get-Encoding "$path").Encoding -ne "UTF8") {
    
                $CurrentLog = Get-Content "$path" -raw -ErrorAction SilentlyContinue
                $currentlog | out-file "$path" -Encoding utf8 -Force -ErrorAction SilentlyContinue
            }
            if ((Get-ItemProperty -Path $path).length -gt $MaxSize) {
    
                Move-Item -Path $path -Destination "$ArchivePath\$(($Path.Split('\')[-1]).Replace('.log',''))-$(Get-Date -Format "yyyyMMdd-HHmmss").log" -Force
            }
        }
        Else {
            If ((Test-Path $path.Substring(0, $path.LastIndexOf('\'))) -eq $false) {
    
                New-item $path.Substring(0, $path.LastIndexOf('\')) -ItemType Directory -Force
            }
        }
    }
    Process {
        $Date = Get-Date -Format "MM-dd-yyyy"
        $Time = Get-Date -Format "HH:mm:ss.ffffff"
        
        if ([string]::IsNullOrEmpty($message)) {
    
            $Message = " "
        }
        else {
            
            # Write the Message to the Screen
            Write-Host $Message
        }
    
        # Write the Message to the Log File
        #$tolog = "$Message `$$<$Component><$Date $Time><thread=$pid>`n"
        $tolog = "<![LOG[$Message]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Severity`" thread=`"$PID`">"
        $tolog | Out-File -FilePath "$path" -Append utf8 -Force
    }
}

function Set-MeridianBCRegKey {

        # -----------------------------
        # SECTION 1: HKLM WorkspaceDB
        # -----------------------------
        
        $Path  = 'HKLM:\SOFTWARE\Cyco\AutoManagerMeridian\CurrentVersion\Client'
        $Name  = 'WorkSpaceDB'
        $Value = 8
        $Type  = 'DWord'

        if (-not (Test-Path -LiteralPath $Path)) {
            
                Write-Log "Creating registry path: $Path"
                New-Item -Path $Path -Force | Out-Null
            }

        $props = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue
        $exists = $props -and ($props.PSObject.Properties.Name -contains $Name)

        if (-not $exists) {
                
                Write-Log "Creating '$Name' with value '$Value' under $Path"
                New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        }
        else {
            
            if ($props.$Name -ne $Value) {
                
                Write-Log "Updating '$Name' from '$($props.$Name)' to '$Value' under $Path"
                Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value
            }
            else {
                
                Write-Log "'$Name' already set to '$Value' under $Path"
            }
        }

        <# Verification loop
        $Verified = $false
        $Timeout = (Get-Date).AddSeconds(10)

        do {
            try {
                    $readValue = Get-ItemPropertyValue -LiteralPath $Path -Name $Name -ErrorAction Stop
                    
                    if ($readValue -eq $Value) {
                        $Verified = $true
                        break
                }
            } 
            
                    catch {}
                
                Start-Sleep -Milliseconds 300
            
            }  while ((Get-Date) -lt $Timeout)

                        if ($Verified) { Write-Log "Verified HKLM key '$Name' successfully set to '$Value'" }

                    else { Write-Log "ERROR: HKLM key '$Name' DID NOT verify correctly. Last read: $readValue" }
        #>

        # -----------------------------------------
        # SECTION 2: HKCU AutocadLink - AcadBaseConfig
        # -----------------------------------------
        $PathACAD  = 'HKCU:\Software\Cyco\AutoManager Meridian\CurrentVersion\AutocadLink'
        $NameACAD  = 'AcadBaseConfig'
        $ValueACAD = 32
        $TypeACAD  = 'DWord'

            if (-not (Test-Path -LiteralPath $PathACAD)) {
            
                    Write-Log "Creating registry path: $PathACAD"
                    New-Item -Path $PathACAD -Force | Out-Null
                }

        $propsACAD = Get-ItemProperty -LiteralPath $PathACAD -ErrorAction SilentlyContinue
        $existsACAD = $propsACAD -and ($propsACAD.PSObject.Properties.Name -contains $NameACAD)

        if (-not $existsACAD) {
                
                Write-Log "Creating '$NameACAD' with value '$ValueACAD' under $PathACAD"
                New-ItemProperty -LiteralPath $PathACAD -Name $NameACAD -Value $ValueACAD -PropertyType $TypeACAD -Force | Out-Null
            }
        
        else {
                if ($propsACAD.$NameACAD -ne $ValueACAD) {
            
                    Write-Log "Updating '$NameACAD' from '$($propsACAD.$NameACAD)' to '$ValueACAD' under $PathACAD"
                    Set-ItemProperty -LiteralPath $PathACAD -Name $NameACAD -Value $ValueACAD
                }
                else {
                    Write-Log "'$NameACAD' already set to '$ValueACAD' under $PathACAD"
                }
            }

        <# Verification loop
        $VerifiedACAD = $false
        $TimeoutACAD = (Get-Date).AddSeconds(10)

        do {
            try {
                    $readValueACAD = Get-ItemPropertyValue -LiteralPath $PathACAD -Name $NameACAD -ErrorAction Stop
                    if ($readValueACAD -eq $ValueACAD) {
                        $VerifiedACAD = $true
                        break
                    }
                } catch {}
            
                Start-Sleep -Milliseconds 300

            } while ((Get-Date) -lt $TimeoutACAD)

            if ($VerifiedACAD) { Write-Log "Verified HKCU key '$NameACAD' successfully set to '$ValueACAD'" }
            
        else { Write-Log "ERROR: HKCU key '$NameACAD' DID NOT verify correctly. Last read: $readValueACAD" }
        
        #>

}

Function Get-InstalledSoftware {
    # Retrieve installed software name, uninstall string, and version from the registry and reformat msiexec strings as necessary
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$SoftwareName,
        [Parameter(Mandatory = $false)]
        [Switch]$Match,
        [Parameter(Mandatory = $false)]
        [Switch]$UserInstall
    )
    $InstalledSoftware = @()
    $InstalledSoftware64 = @()
    If ($UserInstall.IsPresent) {
        $AllInstalledSoftware = Get-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, UninstallString, DisplayVersion, InstallLocation | Sort-Object DisplayName
    }
    Else {
        $InstalledSoftware32 = Get-ItemProperty HKLM:\software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, UninstallString, DisplayVersion, InstallLocation
        if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
            $InstalledSoftware64 = Get-ItemProperty HKLM:\software\wow6432node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, UninstallString, DisplayVersion, InstallLocation
        }
        $AllInstalledSoftware = ($InstalledSoftware32 + $InstalledSoftware64) | Sort-Object DisplayName
    }
    ForEach ($Software in $AllInstalledSoftware) {
        if (![string]::IsNullOrEmpty($Software.DisplayName)) {
            if ($Software.UninstallString -like "*msiexec*") {
                $UninstallStr = $Software.UninstallString
                $UninstallStr = (($UninstallStr.ToLower()) -replace ("msiexec.exe /i", "msiexec.exe /x")) + " /qb!- /norestart"
            }
            elseif (![string]::IsNullOrEmpty($Software.UninstallString)) {
                $UninstallExe = '"' + $Software.UninstallString.Substring(0, ($Software.UninstallString.ToLower().IndexOf("exe") + 3)).TrimStart('"') + '"'
                $UninstallStr = $UninstallExe + $Software.UninstallString.Substring(($Software.UninstallString.ToLower().IndexOf("exe") + 3)).TrimStart('"') + " /S"
            }
            else {
                $uninstallstr = $null
            }
            $DisplayName = $Software.DisplayName
            $version = $Software.DisplayVersion
            $InstallLocation = $Software.InstallLocation
            $InstalledSoftware += [pscustomobject]@{'SoftwareName' = $DisplayName; 'UninstallString' = $uninstallstr; 'Version' = $version; 'InstallLocation' = $InstallLocation; 'UninstallExe' = $uninstallexe }
            If ($UninstallExe) { Remove-Variable -Name Uninstallexe }
            If ($UninstallStr) { Remove-Variable -Name UninstallStr }
        }
    }
    if (-not([string]::IsNullOrEmpty($SoftwareName))) {
        If ($Match.IsPresent) {
            $InstalledSoftware | Where-Object { $_.softwarename -match "$SoftwareName" }
        }
        Else {
            $InstalledSoftware | Where-Object { $_.softwarename -like "*$SoftwareName*" }
        }
    }
    else {
        $InstalledSoftware
    }
}

Function get-SoftwareInstalledBool { 

        $SoftwareIsInstalled = Get-InstalledSoftware -SoftwareName $name

        if ($SoftwareIsInstalled) {$SoftwareisInstalled = $true} 
        else { $SoftwareIsInstalled = $false}

        return $SoftwareIsInstalled
}

Function Uninstall-Software {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [String]$SoftwareName,
        [Parameter(Mandatory = $false, Position = 1)]
        [AllowNull()]
        [AllowEmptyString()]
        [String]$UninstallSwitches,
        [Parameter(Mandatory = $false)]
        [Switch]$Match,
        [Parameter(Mandatory = $false)]
        [Switch]$UserInstall
    )
    Begin {
       
        Write-Log  "--Uninstallation Begin"
    }

    Process {

        If ($Match.IsPresent) {
            
                If ($UserInstall.IsPresent) { $Software = Get-InstalledSoftware -SoftwareName $SoftwareName -Match -UserInstall }
                Else { $Software = Get-InstalledSoftware -SoftwareName $SoftwareName -Match }
        }
        
        Else {
                If ($UserInstall.IsPresent) { $Software = Get-InstalledSoftware -SoftwareName $SoftwareName -UserInstall }
                
                Else { $Software = Get-InstalledSoftware -SoftwareName $SoftwareName }
            }

            Write-Host $Software "the software has been found" -ForegroundColor Red

        
        Foreach ($Product in $Software) {
            
                If ($Product.SoftwareName -like "*$SoftwareName*") {
                    
                        Write-Log "The current version of $($Product.SoftwareName) installed is $($Product.Version)"
                    
                        If (-not([String]::IsNullOrWhiteSpace($UninstallSwitches)) -and -not($Product.UninstallString -match "msiexec")) {
                            
                                $Result = Start-Process cmd -ArgumentList "/c $($Product.UninstallExe) $UninstallSwitches" -PassThru -NoNewWindow -Wait
                        }
                    
                        Else { $Result = Start-Process cmd -ArgumentList "/c $($Product.UninstallString)" -PassThru -NoNewWindow -Wait }
                    
                        Do { Start-Sleep -Milliseconds 500 } Until($Result.HasExited) 

                        Write-Log "Uninstallation of $($Product.SoftwareName) version $($Product.Version) returned exit code $($Result.ExitCode)"
            
            
                }
        }
    }

    End { Write-Log "--Uninstallation End" }
}


Function Install-Software {
    # Install software using provided switches
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$FileName,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$Switches,
        [Parameter(Mandatory = $false)]
        [String]$Name,
        [Parameter(Mandatory = $false)]
        [Switch]$Match
    )
    If ($FileName -like "*.msi") {
        $FileName = "msiexec.exe /i " + $FileName
    }
    Write-Log "--Installation Begin"
    $results = Start-Process cmd -argumentlist "/c $FileName $Switches" -PassThru -NoNewWindow -wait


    Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
    $exitcode = $results.ExitCode
    
    If ($exitcode -eq 0 -or $exitcode -eq 1707 -or $exitcode -eq 3010) {
        Write-Log "Installation succeeded with exit code: $exitcode. No reboot required"
    }
    
    elseif ($exitcode -eq 1641) {
        write-log "Installation succeeded with exit code: $exitcode. A reboot is required."
    }
    else {
        Write-Log "Installation failed with exit code: $exitcode"
    }
    
    If ([String]::IsNullOrWhiteSpace($Name)) {
        If ($Match.IsPresent) {
            $installedsoftware = Get-InstalledSoftware $global:softwarename -Match
        }
        Else {
            $installedsoftware = Get-InstalledSoftware $global:softwarename
        }
    }
    Else {
        If ($Match.IsPresent) {
            $installedsoftware = Get-InstalledSoftware $Name -Match
        }
        Else {
            $installedsoftware = Get-InstalledSoftware $Name
        }
    }
    foreach ($software in $installedsoftware) {
        Write-Log "The currently installed version of $($Software.SoftwareName) is $($Software.Version)"
    }
    Write-Log "--Installation End"
}

Function Write-ScriptErrors {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        $ErrorCollection
    )
    if ($ErrorCollection.count -gt 0) {
        if ($errorcollection.invocationinfo.positionmessage | ? { $_ -notmatch "stop-process" -and $_ -notmatch "stop-service" }) {
            Write-Log "The following errors were encountered:"
            $ErrorCollection = ($ErrorCollection | % { $_.exception.message + $_.InvocationInfo.PositionMessage }) -replace ("\n", " ")
            $ErrorCollection | % { if ($_ -notmatch "Stop-Process") { write-log $_ } }
        }
    }
}

Function Import-LocalPolicy {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [String]$PolicyPath = "$PSScriptRoot\Policy",
        [Parameter(Mandatory = $false)]
        [String]$DefinitionsPath = "$PSScriptRoot\Policy\PolicyDefinitions",
        [Parameter(Mandatory = $false)]
        [String]$LGPOToolPath = "$PSScriptRoot\Policy\LGPO.exe"
    )
    # Copy Policy Definitions to local store
    Write-Log "Copying Group Policy Definitions"
    Copy-Item -Path $DefinitionsPath\* -Destination $env:SystemRoot\PolicyDefinitions -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    
    # Import Policy Files
    Write-Log "Importing local policies"
    $TextPolicyFiles = (Get-Item $PolicyPath\* -Include *.txt).FullName
    Foreach ($Policy in $TextPolicyFiles) {
        Try {
            $Result = Start-Process $LGPOToolPath -ArgumentList "/t $Policy /v"
            Write-Log ($Result | ? { $_ -ne "" })
        }
        Catch {
            Write-Log $_
            Return
        }
    }
    Write-Log "Policy import complete"
}

Function Get-CNDistinguishedName {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias("Cn")]
        [String]$ComputerName = $env:COMPUTERNAME
    )
    [String]$DistinguishedName = ([adsisearcher]"sAMAccountName=$($ComputerName)$").FindOne().Properties.distinguishedname
    $DistinguishedName
}

Function Get-CNGroupMemberships {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias("Cn")]
        [String]$ComputerName = $env:COMPUTERNAME
    )
    [Object]$MemberOf = ([adsisearcher]"sAMAccountName=$($ComputerName)$").FindOne().Properties.memberof | ForEach-Object { $_.Split(",")[0].Split("=")[-1] } | Sort-Object
    $MemberOf
}

Function Get-UNDistinguishedName {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias("Un")]
        [String]$UserName = $env:USERNAME
    )
    [String]$DistinguishedName = ([adsisearcher]"sAMAccountName=$($UserName)").FindOne().Properties.distinguishedname
    $DistinguishedName
}

Function Get-UNGroupMemberships {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias("Un")]
        [String]$UserName = $env:USERNAME
    )
    [Object]$MemberOf = ([adsisearcher]"sAMAccountName=$($UserName)").FindOne().Properties.memberof | ForEach-Object { $_.Split(",")[0].Split("=")[-1] } | Sort-Object
    $MemberOf
}

Function Set-Tattoo {
    [cmdletbinding(DefaultParameterSetName = 'Default')]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Add')]
        [Parameter(ParameterSetName = 'Remove')]
        [String]$Publisher,
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Add')]
        [Parameter(ParameterSetName = 'Remove')]
        [String]$SoftwareName,
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'Add')]
        [String]$Version,
        [Parameter(Mandatory = $true, ParameterSetName = 'Remove')]
        [Switch]$Clean,
        [Parameter(Mandatory = $false)]
        [Switch]$UserInstall,
        [Parameter(Mandatory = $false)]
        [String]$RegRelativePath = "Apps"
    )
    If ($UserInstall.IsPresent) {
        $REG = "HKCU:\Software\DOI\$RegRelativePath"
    }
    Else {
        $REG = "HKLM:\Software\DOI\$RegRelativePath"
    }
    If (!($Clean.IsPresent)) {
        If (!(Test-Path "$REG\$Publisher\$SoftwareName")) {
            New-Item "$REG\$Publisher\$SoftwareName" -Force | Out-Null
        }
        New-ItemProperty "$REG\$Publisher\$SoftwareName" -Name InstalledVersion -PropertyType STRING -Value $Version -Force | Out-Null
    }
    Else {
        Remove-Item "$REG\$Publisher\$SoftwareName" -Force
    }
}
#endregion

#region Preinstallation tasks

Function Close-RForWindows {
    Write-Log "Stopping all R for Windows processes"
    Stop-Process -Name "R for Windows" -Force -ErrorAction SilentlyContinue
}

Function Close-ShareX {
    Write-Log "Stopping all ShareX processes"
    Stop-Process -Name ShareX -Force -ErrorAction SilentlyContinue
}

Function Close-VSCode {
    Write-Log "Stopping all Visual Studio Code processes"
    Stop-Process -Name Code -Force -ErrorAction SilentlyContinue
}
Function Close-DellCommandUpdate {
    Write-Log "Stopping all Dell | Command Update Processes"
    Stop-Process -Name DellCommandUpdate -Force -ErrorAction SilentlyContinue
}

Function Close-Athoc {
    Write-Log "Stopping all AtHoc Processes"
    Stop-Process -name AtHocArmyENT -force -ErrorAction SilentlyContinue
}
Function Close-Chrome {
    Write-Log "Stopping all Chrome Processes"
    Stop-Process -Name GoogleUpdate -Force -ErrorAction SilentlyContinue
    Stop-Process -Name chrome -force -ErrorAction SilentlyContinue
    Stop-Process -Name googlecrashhandler -Force -ErrorAction SilentlyContinue
    Stop-Process -Name googlecrashhandler64 -Force -ErrorAction SilentlyContinue
}
Function Close-IE {
    Write-Log "Stopping all iexplore processes"
    Stop-Process -name iexplore -force -erroraction silentlycontinue
}
Function Close-msiexec {
    Write-Log "Stopping all MSIEXEC processes"
    Stop-Process -Name msiexec -Force -ErrorAction SilentlyContinue
}
Function Close-Firefox {
    Write-Log "Stopping Firefox and Firefox Plugin Processes"
    Stop-Process -Name plugin-container -Force -ErrorAction SilentlyContinue
    Stop-Process -Name firefox -Force -ErrorAction SilentlyContinue
}
Function Close-Java {
    Write-Log "Stopping Java Related Processes"
    Stop-Process -Name java -Force -ErrorAction SilentlyContinue
    Stop-Process -Name javaw -Force -ErrorAction SilentlyContinue
    Stop-Process -Name javaws -Force -ErrorAction SilentlyContinue
    Stop-Process -Name jp2launcher -Force -ErrorAction SilentlyContinue
    Stop-Process -Name lptonesvc -Force -ErrorAction SilentlyContinue
}
Function Close-AdobeAcrobat {
    write-log "Stopping all Acrobat Processes and Services"
    Stop-Process -Name msiexec -Force -ErrorAction SilentlyContinue
    Stop-Process -Name AcroRd -Force -ErrorAction SilentlyContinue
    Stop-Process -Name AcroRd32 -Force -ErrorAction SilentlyContinue
    Stop-Process -Name acrotray -Force -ErrorAction SilentlyContinue
    Stop-Process -Name armsvc -Force -ErrorAction SilentlyContinue
    Stop-Process -Name Acrobat -Force -ErrorAction SilentlyContinue
    Stop-Service -DisplayName AdobeARMservice -Force -ErrorAction SilentlyContinue
}
Function Close-Outlook {
    Stop-Process -name outlook -force -ErrorAction SilentlyContinue
}
Function Close-Acad {
    Write-Log "Stopping all Acad Processes"
    Stop-Process -Name acad -force -ErrorAction SilentlyContinue
}
Function Close-PDapp {
    Write-Log "Stopping all PDapp Processes"
    Stop-Process -Name pdapp -force -ErrorAction SilentlyContinue
}
Function Close-CreativeCloud {
    Write-Log "Stopping all Creative Cloud Processes"
    Stop-Process -Name creativecloudpackager -force -ErrorAction SilentlyContinue
}
Function Close-Project {
    Write-Log "Stopping all Project Processes"
    Stop-Process -Name winproj -force -ErrorAction SilentlyContinue
}
Function Close-Access {
    Write-Log "Stopping all Access Processes"
    Stop-Process -Name MSACCESS -force -ErrorAction SilentlyContinue
}
Function Close-Powerpnt {
    Write-Log "Stopping all Powerpnt Processes"
    Stop-Process -Name POWERPNT -force -ErrorAction SilentlyContinue
}
Function Close-Excel {
    Write-Log "Stopping all Excel Processes"
    Stop-Process -Name EXCEL -force -ErrorAction SilentlyContinue
}
Function Close-Word {
    Write-Log "Stopping all Word Processes"
    Stop-Process -Name winword -force -ErrorAction SilentlyContinue
}

Function Close-Snagit {
    Write-Log "Stopping all Snagit Processes"
    Stop-Process -Name Snagit32 -Force -ErrorAction SilentlyContinue
    Stop-Process -Name SnagitEditor -Force -ErrorAction SilentlyContinue
    Stop-Process -Name SnagPriv -Force -ErrorAction SilentlyContinue
}
#endregion

#region Custom Functions

#region R for Windows Functions

Function Uninstall-RForWindows {
    # Uninstall software that matches the software name provided (uninstalls all matches e.g. "adobe" removes all adobe products)
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]$SoftwareName = "R for Windows"
    )
    Begin {
        If (-not([String]::IsNullOrWhiteSpace($SoftwareName))) {
            $Software = Get-InstalledSoftware -SoftwareName $SoftwareName
        }
    }
    Process {
        Write-Log "--Uninstallation Begin"
        If ($Input.SoftwareName -like "*$SoftwareName*") {
            Write-Log "The current version of $($Input.SoftwareName) installed is $($Input.Version)"
            $Result = Start-Process cmd -ArgumentList "/c $($Input.UninstallString.Replace("/S","/SILENT"))" -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 }Until($Result.HasExited)
            Write-Log "Uninstallation of $($Input.SoftwareName) version $($Input.Version) returned exit code $($Result.ExitCode)"
        }
        ElseIf ($Software.SoftwareName -like "*$SoftwareName*") {
            Write-Log "The current version of $($Software.SoftwareName) installed is $($Software.Version)"
            $Result = Start-Process cmd -ArgumentList "/c $($Software.UninstallString.Replace("/S","/SILENT"))" -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 }Until($Result.HasExited)
            Write-Log "Uninstallation of $($Software.SoftwareName) version $($Input.Version) returned exit code $($Result.ExitCode)"
        }
    }
    End {
        Write-Log "--Uninstallation End"
    }
    <# Old function - Updated 11/20/2024 to support piping for user installed software
    Write-Log "--Uninstallation Begin"
    $InstalledSoftware = Get-InstalledSoftware -softwarename $SoftwareName
    ForEach ($software in $installedsoftware) {
        if ($software.softwarename -like "*$SoftwareName*") {
            $version = $software.Version
            $name = $Software.SoftwareName
            $strUninstall = $software.uninstallstring
            Write-Log "The current version of $SoftwareName installed is $version"
            $results = Start-Process cmd -argumentlist "/c $strUninstall" -PassThru -NoNewWindow -wait
            Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
            $exitcode = $results.ExitCode
            Write-Log "Uninstallation of $Name version $version returned exit code $exitcode"
        }
    }
    Write-Log "--Uninstallation End"
    #>
}
Function Uninstall-ShareX {
    # Uninstall software that matches the software name provided (uninstalls all matches e.g. "adobe" removes all adobe products)
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]$SoftwareName = 'ShareX'
    )
    Begin {
        If (-not([String]::IsNullOrWhiteSpace($SoftwareName))) {
            $Software = Get-InstalledSoftware -SoftwareName $SoftwareName
        }
    }
    Process {
        Write-Log "--Uninstallation Begin"
        If ($Input.SoftwareName -like "*$SoftwareName*") {
            Write-Log "The current version of $($Input.SoftwareName) installed is $($Input.Version)"
            $Result = Start-Process cmd -ArgumentList "/c $($Input.UninstallString.Replace("/S","/SILENT"))" -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 }Until($Result.HasExited)
            Write-Log "Uninstallation of $($Input.SoftwareName) version $($Input.Version) returned exit code $($Result.ExitCode)"
        }
        ElseIf ($Software.SoftwareName -like "*$SoftwareName*") {
            Write-Log "The current version of $($Software.SoftwareName) installed is $($Software.Version)"
            $Result = Start-Process cmd -ArgumentList "/c $($Software.UninstallString.Replace("/S","/SILENT"))" -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 }Until($Result.HasExited)
            Write-Log "Uninstallation of $($Software.SoftwareName) version $($Input.Version) returned exit code $($Result.ExitCode)"
        }
    }
    End {
        Write-Log "--Uninstallation End"
    }
    <# Old function - Updated 11/20/2024 to support piping for user installed software
    Write-Log "--Uninstallation Begin"
    $InstalledSoftware = Get-InstalledSoftware -softwarename $SoftwareName
    ForEach ($software in $installedsoftware) {
        if ($software.softwarename -like "*$SoftwareName*") {
            $version = $software.Version
            $name = $Software.SoftwareName
            $strUninstall = $software.uninstallstring
            Write-Log "The current version of $SoftwareName installed is $version"
            $results = Start-Process cmd -argumentlist "/c $strUninstall" -PassThru -NoNewWindow -wait
            Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
            $exitcode = $results.ExitCode
            Write-Log "Uninstallation of $Name version $version returned exit code $exitcode"
        }
    }
    Write-Log "--Uninstallation End"
    #>
}

#endregion

#region ShareX Functions

Function Uninstall-ShareX {
    # Uninstall software that matches the software name provided (uninstalls all matches e.g. "adobe" removes all adobe products)
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]$SoftwareName = 'ShareX'
    )
    Begin {
        If (-not([String]::IsNullOrWhiteSpace($SoftwareName))) {
            $Software = Get-InstalledSoftware -SoftwareName $SoftwareName
        }
    }
    Process {
        Write-Log "--Uninstallation Begin"
        If ($Input.SoftwareName -like "*$SoftwareName*") {
            Write-Log "The current version of $($Input.SoftwareName) installed is $($Input.Version)"
            $Result = Start-Process cmd -ArgumentList "/c $($Input.UninstallString.Replace("/S","/SILENT"))" -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 }Until($Result.HasExited)
            Write-Log "Uninstallation of $($Input.SoftwareName) version $($Input.Version) returned exit code $($Result.ExitCode)"
        }
        ElseIf ($Software.SoftwareName -like "*$SoftwareName*") {
            Write-Log "The current version of $($Software.SoftwareName) installed is $($Software.Version)"
            $Result = Start-Process cmd -ArgumentList "/c $($Software.UninstallString.Replace("/S","/SILENT"))" -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 }Until($Result.HasExited)
            Write-Log "Uninstallation of $($Software.SoftwareName) version $($Input.Version) returned exit code $($Result.ExitCode)"
        }
    }
    End {
        Write-Log "--Uninstallation End"
    }
    <# Old function - Updated 11/20/2024 to support piping for user installed software
    Write-Log "--Uninstallation Begin"
    $InstalledSoftware = Get-InstalledSoftware -softwarename $SoftwareName
    ForEach ($software in $installedsoftware) {
        if ($software.softwarename -like "*$SoftwareName*") {
            $version = $software.Version
            $name = $Software.SoftwareName
            $strUninstall = $software.uninstallstring
            Write-Log "The current version of $SoftwareName installed is $version"
            $results = Start-Process cmd -argumentlist "/c $strUninstall" -PassThru -NoNewWindow -wait
            Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
            $exitcode = $results.ExitCode
            Write-Log "Uninstallation of $Name version $version returned exit code $exitcode"
        }
    }
    Write-Log "--Uninstallation End"
    #>
}

#endregion
#region Custom  MARK 43 CAD  uninstall


Function Uninstall-Mark43Cad {
    # Uninstall Mark 43 CAD using vendor EXE in InstallLocation with /S
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]$SoftwareName = 'Mark43 CAD*'
    )

    Begin {
        if (-not [string]::IsNullOrWhiteSpace($SoftwareName)) {
            # IMPORTANT: assign to $Software
            $Software = Get-InstalledSoftware -SoftwareName $SoftwareName
        }
    }

    Process {
        Write-Log "--Uninstallation Begin"

        if (-not $Software) {
            Write-Log "No software found matching '$SoftwareName'."
            Write-Log "--Uninstallation End"
            return
        }

        foreach ($target in @($Software)) {
            Write-Log "Detected $($target.SoftwareName) version $($target.Version)"

            # Build the full path from InstallLocation + 'Uninstall Mark43CAD.exe'
            $exeName = 'Uninstall Mark43CAD.exe'
            $fullPath = Join-Path $target.InstallLocation $exeName
            Write-Log "Uninstaller path: $fullPath"

            if (-not (Test-Path $fullPath)) {
                Write-Log "Uninstaller not found at: $fullPath"
                continue
            }

            # Execute vendor uninstaller via cmd, explicitly adding /S
            $cmdArgs = '/c "' + $fullPath + '" /S'
            $Result = Start-Process cmd -ArgumentList $cmdArgs -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 } Until ($Result.HasExited)

            Write-Log "Uninstallation of $($target.SoftwareName) returned exit code $($Result.ExitCode)"
        }
    }

    End {
        Write-Log "--Uninstallation End"
    }
}
#endregion

#region Custom Master Application Functions

Function Install-MasterApp {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [Switch]$UserApp,
        [Parameter(Mandatory = $true)]
        [String]$Publisher,
        [Parameter(Mandatory = $true)]
        [String]$ProductName
    )
    If ($UserApp.IsPresent) {
        $Reg = "HKCU:\Software\DOI\NPS\$Publisher\$ProductName"
    }
    Else {
        $Reg = "HKLM:\Software\DOI\NPS\$Publisher\$ProductName"
    }
    If (-not(Test-Path -Path $Reg)) {
        New-Item -Path $Reg -Force | Out-Null
    }
    New-ItemProperty -Path $Reg -Name MasterApp -PropertyType STRING -Value (Get-Date -Format 'yyyy-MM-dd') -Force | Out-Null
}

#endregion

#region Visual Studio Code

Function Uninstall-VSCode {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]$SoftwareName = 'Microsoft Visual Studio Code'
    )
    Begin {
        If (-not([String]::IsNullOrWhiteSpace($SoftwareName))) {
            $Software = Get-InstalledSoftware -SoftwareName "^$SoftwareName$" -Match
        }
    }
    Process {
        Write-Log "--Uninstallation Begin"
        If ($Input.SoftwareName -like "*$SoftwareName*") {
            Write-Log "The current version of $($Input.SoftwareName) installed is $($Input.Version)"
            $Result = Start-Process cmd -ArgumentList "/c $($Input.UninstallString.replace('/S','/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'))" -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 }Until($Result.HasExited)
            Write-Log "Uninstallation of $($Input.SoftwareName) version $($Input.Version) returned exit code $($Result.ExitCode)"
        }
        ElseIf ($Software.SoftwareName -like "*$SoftwareName*") {
            Write-Log "The current version of $($Software.SoftwareName) installed is $($Software.Version)"
            $Result = Start-Process cmd -ArgumentList "/c $($Software.UninstallString.replace('/S','/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'))" -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 }Until($Result.HasExited)
            Write-Log "Uninstallation of $($Software.SoftwareName) version $($Input.Version) returned exit code $($Result.ExitCode)"
        }
    }
    End {
        Write-Log "--Uninstallation End"
    }
}

#endregion

#region GIT

Function Uninstall-Git {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]$SoftwareName = 'Git'
    )
    Begin {
        If (-not([String]::IsNullOrWhiteSpace($SoftwareName))) {
            $Software = Get-InstalledSoftware -SoftwareName "^$SoftwareName$" -Match
        }
    }
    Process {
        Write-Log "--Uninstallation Begin"
        If ($Input.SoftwareName -like "*$SoftwareName*") {
            Write-Log "The current version of $($Input.SoftwareName) installed is $($Input.Version)"
            $Result = Start-Process cmd -ArgumentList "/c $($Input.UninstallString.replace('/S','/VERYSILENT /NORESTART'))" -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 }Until($Result.HasExited)
            Write-Log "Uninstallation of $($Input.SoftwareName) version $($Input.Version) returned exit code $($Result.ExitCode)"
        }
        ElseIf ($Software.SoftwareName -like "*$SoftwareName*") {
            Write-Log "The current version of $($Software.SoftwareName) installed is $($Software.Version)"
            $Result = Start-Process cmd -ArgumentList "/c $($Software.UninstallString.replace('/S','/VERYSILENT /NORESTART'))" -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 }Until($Result.HasExited)
            Write-Log "Uninstallation of $($Software.SoftwareName) version $($Input.Version) returned exit code $($Result.ExitCode)"
        }
    }
    End {
        Write-Log "--Uninstallation End"
    }
}

#endregion

#region Custom Dell Functions

Function  Set-DellBIosUpdate {
    $BIOStask = Get-ScheduledTask  -TaskName  "Scheduled DellBIOS Update" -TaskPath "\NPS\" -ErrorAction SilentlyContinue | Out-Null            
    if (!$BIOStask) {
        $service = new-object -comobject Schedule.Service               
        $TaskName = "Scheduled DellBIOS Update"               
        # The description of the task               
        $TaskDescr = "Run  Schdeduled Dell Update for BIOS  once a month 1st  at 16:30 "             
        # The Task Action command          
        $TaskCommand = '"C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"'          
        # The PowerShell script to be executed          
        # The Task Action command argument          
        $TaskArg = "/applyUpdates -updateType=bios -autoSuspendBitLocker=enable"      
        $service.connect()        
        #see if the folder exist if not c     
        try {       
            $npsfolder = $service.GetFolder("NPS")        
        }          
        catch {      
            $rootfolder = $service.GetFolder("\")          
            $rootfolder.CreateFolder("NPS")         
            $npsfolder = $service.GetFolder("NPS")       
        }        
        try {       
            $npsfolder = $service.GetFolder("NPS")    
            $npsfolder.GetTask("Scheduled DellBIOS Update")     
        }          
        catch {      
            $TaskDefinition = $service.NewTask(0)  
            $TaskDefinition.RegistrationInfo.Description = "$TaskDescr"  
            $TaskDefinition.Settings.Enabled = $true    
            $TaskDefinition.Settings.AllowDemandStart = $true  
            $triggers = $TaskDefinition.Triggers  
            $trigger = $triggers.Create(4)
            $trigger.DaysOfMonth = 1                                                                                                                                                                                                                                                                                       
            $trigger.StartBoundary = ([datetime]::Now).ToString("2021-09-01'T'16:30:00")  
            $Action = $TaskDefinition.Actions.Create(0)       
            $action.Path = "$TaskCommand"      
            $action.Arguments = "$TaskArg"      
            $npsfolder.RegisterTaskDefinition("$TaskName", $TaskDefinition, 6, "System", $null, 5)     
            Write-Host $true      
        }    
    }  
}  

#endregion

#region Custom Chrome Functions
Function Uninstall-Chrome {
    Write-Log "Uninstallation Begin"
    $InstalledSoftware = Get-InstalledSoftware -softwarename "Google Chrome"
    ForEach ($software in $installedsoftware) {
        if ($software.softwarename -like "*$SoftwareName*") {
            $version = $software.Version
            $name = $Software.SoftwareName
            $strUninstall = $software.uninstallstring
            if ($strUninstall -match "setup.exe") {
                $strUninstall = $strUninstall.TrimEnd("`" /S") + " --multi-install --chrome --force-uninstall" -replace ("setup.exe", "setup.exe`"")
            }
            Write-Log "The current version of $SoftwareName installed is $version"
            $results = Start-Process cmd -argumentlist "/c $strUninstall" -PassThru -NoNewWindow -wait
            Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
            $exitcode = $results.ExitCode
            Write-Log "Uninstallation of Google Chrome version $version returned exit code $exitcode"
        }
    }
    Get-ItemProperty HKLM:\SOFTWARE\AGMProgram\Build\Update\Installed\* | ? applicationname -like "*Google Chrome*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Log "Uninstallation End"
}
Function Disable-ChromeUpdate {
    (Get-WmiObject win32_service | ? name -Match gupdate).delete()
}

Function Start-ChromeCleanup {
    Write-Log "Starting Chrome Cleanup"
    #remove left over directories to ensure installation succeeds
    Remove-Item "$env:ProgramW6432\Google\Chrome" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item "$env:ProgramW6432\Google\Update" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item "$env:ProgramW6432\Google\CrashReports" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item "${env:ProgramFiles(x86)}\Google\Chrome" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item "${env:ProgramFiles(x86)}\Google\Update" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item "${env:ProgramFiles(x86)}\Google\CrashReports" -Force -Recurse -ErrorAction SilentlyContinue
    Write-Log "--Chrome Cleanup Finished"
}
#endregion
#region Notepad++
function Set-NotepadPPAutoUpdate {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "$env:APPDATA\Notepad++\config.xml",
        [switch]$AllUsers,
        [switch]$Template
    )

    function Test-XmlFile {
        [CmdletBinding()]
        param([Parameter(Mandatory)][string]$Path)
        try {
            [xml]$null = Get-Content -Path $Path -Raw -ErrorAction Stop
            if (Get-Command Write-Log -ErrorAction SilentlyContinue) { Write-Log "XML is well-formed: $Path" }
            return $true
        }
        catch {
            $ex = $_.Exception; $ln = $ex.LineNumber; $col = $ex.LinePosition; $msg = $ex.Message
            if (Get-Command Write-Log -ErrorAction SilentlyContinue) { Write-Log "XML ERROR in $Path at line $ln, column $col $msg" }
            return $false
        }
    }

    function Repair-XmlIllegalChars {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)][string]$Path,
            [string]$BackupSuffix = '.bak'
        )
        if (-not (Test-Path -Path $Path)) { throw "File not found: $Path" }
        try {
            $raw = Get-Content -Path $Path -Raw -ErrorAction Stop
            $clean = ($raw -replace '[^\x09\x0A\x0D\x20-\xD7FF\xE000-\xFFFD]', '')
            if ($clean -ne $raw) {
                Copy-Item -Path $Path -Destination ($Path + $BackupSuffix) -Force
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($Path, $clean, $utf8NoBom)
                Write-Log "Removed illegal XML characters (backup: $Path$BackupSuffix)"
                return $true
            }
            else {
                Write-Log "No illegal XML characters found: $Path"
                return $false
            }
        }
        catch {
            Write-Log "Failed to repair illegal XML characters in $Path : $_"
            throw
        }
    }

    function Set-NoUpdateConfig {
        param([Parameter(Mandatory)][string]$Path)

        # DO NOT create the Notepad++ folder; skip if missing
        $dir = Split-Path -Path $Path -Parent
        if (-not (Test-Path -Path $dir)) {
            Write-Log "Skipping: Notepad++ profile folder not found: $dir"
            return
        }

        # Load existing XML or start skeleton ONLY if file exists
        try {
            [xml]$xml = if (Test-Path -Path $Path) {
                if (Test-XmlFile -Path $Path) {
                    Get-Content -Path $Path -Raw
                }
                else {
                    Repair-XmlIllegalChars -Path $Path | Out-Null
                    if (Test-XmlFile -Path $Path) { Get-Content -Path $Path -Raw } else {
                        # Still bad; start minimal skeleton (file exists already, folder exists)
                        $x = New-Object System.Xml.XmlDocument
                        $decl = $x.CreateXmlDeclaration("1.0", "utf-8", $null); $null = $x.AppendChild($decl)
                        $root = $x.CreateElement("NotepadPlus"); $null = $x.AppendChild($root)
                        $x
                    }
                }
            }
            else {
                # Folder exists but file doesn't—OK to create a new config.xml here
                $x = New-Object System.Xml.XmlDocument
                $decl = $x.CreateXmlDeclaration("1.0", "utf-8", $null); $null = $x.AppendChild($decl)
                $root = $x.CreateElement("NotepadPlus"); $null = $x.AppendChild($root)
                $x
            }
        }
        catch {
            $x = New-Object System.Xml.XmlDocument
            $decl = $x.CreateXmlDeclaration("1.0", "utf-8", $null); $null = $x.AppendChild($decl)
            $root = $x.CreateElement("NotepadPlus"); $null = $x.AppendChild($root)
            [xml]$xml = $x
            Write-Log "Started fresh XML skeleton for $Path"
        }

        # Ensure /NotepadPlus/GUIConfigs/GUIConfig[@name='noUpdate']
        $root = $xml.SelectSingleNode('/NotepadPlus'); if (-not $root) { $root = $xml.CreateElement('NotepadPlus'); $null = $xml.AppendChild($root) }
        $gui = $xml.SelectSingleNode('/NotepadPlus/GUIConfigs'); if (-not $gui) { $gui = $xml.CreateElement('GUIConfigs'); $null = $root.AppendChild($gui) }

        $noUpd = $xml.SelectSingleNode("/NotepadPlus/GUIConfigs/GUIConfig[@name='noUpdate']")
        if (-not $noUpd) {
            $noUpd = $xml.CreateElement('GUIConfig')
            $noUpd.SetAttribute('name', 'noUpdate'); $noUpd.SetAttribute('value', 'yes')
            $null = $gui.AppendChild($noUpd)
            Write-Log "Added noUpdate setting to $Path"
        }
        else {
            $noUpd.SetAttribute('value', 'yes')
            Write-Log "Updated noUpdate setting in $Path"
        }

        # Pretty save (UTF-8 no BOM)
        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Indent = $true; $settings.OmitXmlDeclaration = $false
        $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
        $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
        $xml.Save($writer); $writer.Close()
        Write-Log "Saved $Path"
    }

    try {
        # Single path mode (respect: do NOT create Notepad++ folder if absent)
        if ($PSBoundParameters.ContainsKey('ConfigPath') -and -not $AllUsers) {
            $cfgDir = Split-Path -Path $ConfigPath -Parent
            if (Test-Path -Path $cfgDir) {
                Set-NoUpdateConfig -Path $ConfigPath
            }
            else {
                Write-Log "Skipping: Notepad++ profile folder not found: $cfgDir"
            }
        }
        else {
            if ($AllUsers) {
                $profiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue | Where-Object {
                    $_.Name -notin @('Default', 'Default User', 'Public', 'All Users') -and
                    $_.Name -notlike 'WDAGUtilityAccount' -and
                    $_.Name -notlike 'DefaultAppPool'
                }
                foreach ($p in $profiles) {
                    $npDir = Join-Path $p.FullName 'AppData\Roaming\Notepad++'
                    if (Test-Path -Path $npDir) {
                        $cfg = Join-Path $npDir 'config.xml'
                        Set-NoUpdateConfig -Path $cfg
                    }
                    else {
                        Write-Log "Skipping user '$($p.Name)': Notepad++ folder not found: $npDir"
                    }
                }
            }
            else {
                $cfgDir = Split-Path -Path $ConfigPath -Parent
                if (Test-Path -Path $cfgDir) {
                    Set-NoUpdateConfig -Path $ConfigPath
                }
                else {
                    Write-Log "Skipping: Notepad++ profile folder not found: $cfgDir"
                }
            }
        }

        if ($Template) {
            $candidates = @()
            if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles        'Notepad++\config.model.xml') }
            if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Notepad++\config.model.xml') }
            foreach ($tmpl in $candidates) {
                try {
                    $tmplDir = Split-Path -Path $tmpl -Parent
                    if (-not (Test-Path $tmplDir)) { New-Item -ItemType Directory -Path $tmplDir -Force | Out-Null }
                    if (-not (Test-Path $tmpl)) {
                        '<?xml version="1.0" encoding="utf-8"?><NotepadPlus><GUIConfigs/></NotepadPlus>' |
                        Set-Content -Path $tmpl -Encoding UTF8
                        Write-Log "Created template $tmpl"
                    }
                    Set-NoUpdateConfig -Path $tmpl
                }
                catch {
                    Write-Log "Failed to prepare template $tmpl : $_"
                    throw
                }
            }
        }
    }
    catch {
        Write-Log "Set-NotepadPPAutoUpdate failed: $_"
        throw
    }
}

function Remove-NotepadPlusPlusUpdater {
    [CmdletBinding()]
    param()
    
    $updaterPath = Join-Path -Path $env:ProgramFiles -ChildPath "Notepad++\Updater"
    
    if (Test-Path -Path $updaterPath) {
        try {
            Write-Log -Message "Notepad++ Updater folder found at '$updaterPath'. Removing..."
            Remove-Item -Path $updaterPath -Recurse -Force -ErrorAction Stop
            Write-Log -Message "Successfully removed Notepad++ Updater folder."
        }
        catch {
            Write-Log -Message "Failed to remove Notepad++ Updater folder: $($_.Exception.Message)" -Level Error
        }
    }
    else {
        Write-Log -Message "Notepad++ Updater folder not found at '$updaterPath'. Skipping removal."
    }
}
function Remove-RootCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Thumbprint
    )
    
    $certPath = "Cert:\LocalMachine\Root\$Thumbprint"
    
    $cert = Get-Item -Path $certPath -ErrorAction SilentlyContinue
    
    if ($cert) {
        Write-Log -Message "Certificate with thumbprint '$Thumbprint' found in Trusted Root CA store. Removing..."
        Remove-Item -Path $certPath -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Log -Message "Certificate removal attempted."
    }
    else {
        Write-Log -Message "Certificate with thumbprint '$Thumbprint' not found in Trusted Root CA store. Skipping removal."
    }
}

#remove software 
function Remove-NppConfigAllUsers {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [switch]$Backup,             # Save a .bak copy alongside the file before deletion
        [switch]$IncludeDefault,     # Also remove from Default profile template(s) if present
        [switch]$KillNotepad         # Stop any running notepad++.exe before deletion
    )

    # Optional: stop Notepad++ to release any locks
    if ($KillNotepad) {
        Get-Process notepad++ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    $results = New-Object System.Collections.Generic.List[object]

    # Discover user profiles via registry (handles nonstandard locations)
    $profileKeys = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -ErrorAction SilentlyContinue
    foreach ($key in $profileKeys) {
        $profilePath = (Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue).ProfileImagePath
        if ([string]::IsNullOrWhiteSpace($profilePath)) { continue }
        if (-not (Test-Path $profilePath)) { continue }

        # Skip system/service profiles
        $leaf = Split-Path $profilePath -Leaf
        if ($leaf -in @('Default', 'Default User', 'Public', 'All Users', 'DefaultAppPool', 'WDAGUtilityAccount') -or
            $profilePath -match '\\(LocalService|NetworkService|systemprofile)$') { continue }

        $cfg = Join-Path $profilePath 'AppData\Roaming\Notepad++\config.xml'
        if (Test-Path $cfg) {
            try {
                if ($Backup) {
                    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
                    $bak = "$cfg.$stamp.bak"
                    if ($PSCmdlet.ShouldProcess($cfg, "Backup to $bak")) {
                        Copy-Item -Path $cfg -Destination $bak -Force
                    }
                }
                if ($PSCmdlet.ShouldProcess($cfg, "Remove")) {
                    Remove-Item -Path $cfg -Force
                }
                $results.Add([pscustomobject]@{ User = $leaf; Path = $cfg; Action = 'Removed'; BackedUp = [bool]$Backup; Status = 'OK' }) | Out-Null
            }
            catch {
                $results.Add([pscustomobject]@{ User = $leaf; Path = $cfg; Action = 'Remove'; BackedUp = [bool]$Backup; Status = "ERROR: $_" }) | Out-Null
            }
        }
        else {
            $results.Add([pscustomobject]@{ User = $leaf; Path = $cfg; Action = 'Skip'; BackedUp = $false; Status = 'NotFound' }) | Out-Null
        }
    }

    if ($IncludeDefault) {
        # Clean templates so future first-run also has no config.xml
        $defaultCandidates = @(
            'C:\Users\Default\AppData\Roaming\Notepad++\config.xml',
            'C:\Users\Default User\AppData\Roaming\Notepad++\config.xml'
        ) | Where-Object { Test-Path (Split-Path $_ -Parent) } # only consider existing dirs

        foreach ($cfg in $defaultCandidates) {
            if (Test-Path $cfg) {
                try {
                    if ($Backup) {
                        $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
                        $bak = "$cfg.$stamp.bak"
                        if ($PSCmdlet.ShouldProcess($cfg, "Backup to $bak")) {
                            Copy-Item -Path $cfg -Destination $bak -Force
                        }
                    }
                    if ($PSCmdlet.ShouldProcess($cfg, "Remove (Default template)")) {
                        Remove-Item -Path $cfg -Force
                    }
                    $results.Add([pscustomobject]@{ User = 'Default'; Path = $cfg; Action = 'Removed'; BackedUp = [bool]$Backup; Status = 'OK' }) | Out-Null
                }
                catch {
                    $results.Add([pscustomobject]@{ User = 'Default'; Path = $cfg; Action = 'Remove'; BackedUp = [bool]$Backup; Status = "ERROR: $_" }) | Out-Null
                }
            }
            else {
                $results.Add([pscustomobject]@{ User = 'Default'; Path = $cfg; Action = 'Skip'; BackedUp = $false; Status = 'NotFound' }) | Out-Null
            }
        }
    }

    # Output a summary table

}
 
#endregion
#region Custom Firefox Functions
Function Start-FirefoxConfiguration {
    #region user stuff
    $defaultffprofile = "[Profile0]
Name=default
IsRelative=1
Path=Profiles/NPS.DEFAULT
Default=1"

    
    $PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
 
    # Get Username, SID, and location of ntuser.dat for all users
    $ProfileList = (gp 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object { $_.PSChildName -match $PatternSID } | 
        Select  @{n = "Profile"; e = { $_.ProfileImagePath } }).profile

    $ProfileList += 'C:\users\default'

    $ProfileList = $ProfileList | ? { $_ -notmatch "defaultuser0" }

    foreach ($profile in $ProfileList) {
        if (!(Test-Path "$profile\AppData\roaming\mozilla\firefox\profiles.ini")) {
            new-item "$profile\AppData\roaming\Mozilla\FireFox\Profiles\NPS.DEFAULT" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            Start-Sleep -Milliseconds 500
            $defaultffprofile | Out-File "$profile\AppData\roaming\mozilla\firefox\profiles.ini"
            write-log "Copying Smart Card Configuration to profile: $Profile/NPS.Deafult"
            copy-item -Path "$psscriptroot\pkcs11.txt" -Destination "$profile\AppData\Roaming\Mozilla\FireFox\Profiles\NPS.DEFAULT\" -Force
        }
        else {
            $FFProfiles = (Get-Content "$profile\AppData\Roaming\Mozilla\Firefox\profiles.ini" | select-string "path=") -replace "path=", "" -replace "/", "\"
            foreach ($FFProfile in $FFProfiles) {
                If (!(Test-Path -Path "$profile\AppData\Roaming\Mozilla\Firefox\$FFProfile")) {
                    New-Item -ItemType directory -Path "$Profile\AppData\Roaming\Mozilla\Firefox\$FFProfiles"
                }
                write-log "Copying Smart Card Configuration to profile: $Profile/$FFProfile"
                copy-item -Path "$psscriptroot\pkcs11.txt" "$profile\AppData\Roaming\Mozilla\Firefox\$FFProfile" -Force
            }
        }
    }

    #endregion

    #region machine Stuff
    <#    $programpath = "$env:ProgramW6432\Mozilla Firefox"
    if (Get-WmiObject win32_service -ErrorAction SilentlyContinue | ? name -eq mozillamaintenance) {
        write-log "Removing Mozilla Maintenance Service"
        $service = Get-WmiObject win32_service -ErrorAction SilentlyContinue | ? name -eq mozillamaintenance
        $service.delete() | Out-Null

    }
#>  
    $ProgramPath = "$env:ProgramW6432\Mozilla Firefox"
    write-log "Copying Mozilla.cfg to $ProgramPath"
    Copy-Item "$PSScriptRoot\mozilla.cfg" "$ProgramPath\mozilla.cfg" -Force
    if (!(Test-Path "$programpath\defaults\pref")) {
        new-item "$ProgramPath\defaults\pref -ItemType Directory"
    }
    Write-Log "Copying autoconfig.js to $ProgramPath\defaults\pref"
    Copy-Item "$PSScriptRoot\autoconfig.js" "$ProgramPath\defaults\pref" -Force
    if (Test-Path "$PSScriptRoot\override.ini") {
        Copy-Item -Path "$PSScriptRoot\override.ini" -Destination "$programpath\Mozilla Firefox" -Force
    }

    Write-Log "Copying policies.."
    If (!(Test-Path -Path "$ProgramPath\distribution")) {
        New-Item -Path "$ProgramPath\distribution" -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path "$PSScriptRoot\policies.json" -Destination "$ProgramPath\distribution\" -Force
    Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Firefox Private Browsing.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:ProgramW6432\Mozilla Firefox\private_browsing.exe" -Force -ErrorAction SilentlyContinue
    #endregion
    Write-Log " --Mozilla Firefox Post-Installation Tasks End"

} 
#endregion

#region Custom Adobe Flash Functions
Function Uninstall-Flash {
    Write-Log "--Running Flash Uninstaller"
    $results = Start-Process cmd -argumentlist "/c uninstall_flash_player.exe -uninstall" -PassThru -NoNewWindow -wait
    Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
    $exitcode = $results.ExitCode
    If ($exitcode -eq 0 -or $exitcode -eq 1707 -or $exitcode -eq 3010) {
        Write-Log "Removal succeeded with exit code: $exitcode. No reboot required"
    }
    elseif ($exitcode -eq 1641) {
        write-log "Removal succeeded with exit code: $exitcode. A reboot is required."
    }
    else {
        Write-Log "Removal failed with exit code: $exitcode"
    }
    $installedsoftware = Get-InstalledSoftware $SoftwareName
    foreach ($software in $installedsoftware) {
        $name = $Software.SoftwareName
        $version = $Software.Version
        Write-Log "The currently installed version of $name is $version"
    }
    Write-Log "--Removal End"

}
Function Disable-FlashAutoUpdate {
    $FlashSettings = "AutoUpdateDisable=1"
    $FlashSettings | Out-File C:\Windows\System32\Macromed\Flash\mms.cfg -Force -Encoding ascii
    if ($ENV:PROCESSOR_ARCHITECTURE = "AMD64") {
        $FlashSettings | Out-File C:\Windows\syswow64\Macromed\Flash\mms.cfg -Force -encoding ascii
    }
    
    Write-Log "Flash Auto Update Disabled"
}
#endregion

#region Custom Java  Functions

Function Set-JavaExceptionSites {
    $JavaInstallLocations = (Get-InstalledSoftware "JaVa 8").installlocation
    $ExceptionSitesPath = "C:\Windows\Sun\Java\Deployment\exception.sites"
    $ExceptionSites = get-content "$PSScriptRoot\exception.sites"
    Write-Log "Configuring Java Exception Sites"
    If (Test-Path $ExceptionSitesPath -ErrorAction SilentlyContinue) {
        $SystemExceptionSites = Get-Content $ExceptionSitesPath
        foreach ($site in $ExceptionSites) {
            $Exists = $false
            foreach ($SystemSite in $SystemExceptionSites) {
                if ($site.ToLower().trim() -eq $SystemSite.tolower().trim()) {
                    $Exists = $true
                }
            }
            if (!($Exists) -AND !([string]::IsNullOrEmpty($site))) {
                Write-Log "Adding $site to Exception.Sites"
                $site | Out-File -FilePath $ExceptionSitesPath -force -Append -Encoding ascii -ErrorAction SilentlyContinue
            }
        }
    }
    Else {
        Write-Log "Copying Exception.Sites to $ExceptionSitesPath"
        Copy-Item "$PSScriptRoot\exception.sites" $ExceptionSitesPath -force -ErrorAction SilentlyContinue
    }
    (Get-Content $ExceptionSitesPath) | Where { $_.Trim(" `t") } | Set-Content $ExceptionSitesPath -ErrorAction SilentlyContinue
}

Function Copy-JavaConfiguration {
    $JavaLocations = Get-InstalledSoftware "Java 8"

    Write-Log "Copying deployment.properties"
    Copy-Item "$PSScriptRoot\deployment.properties" "C:\windows\Sun\Java\Deployment\" -force -ErrorAction SilentlyContinue    
    foreach ($location in $JavaLocations.InstallLocation) {
        Copy-Item "$PSScriptRoot\deployment.properties" "$location\lib\" -force -ErrorAction SilentlyContinue
    }

    Write-Log "Copying localpolicy.jar"
    foreach ($location in $JavaLocations.InstallLocation) {
        Copy-Item "$PSScriptRoot\local_policy.jar" "$location\lib\security" -force -ErrorAction SilentlyContinue
    }

    Write-Log "Copying deployment.config"
    foreach ($location in $JavaLocations.InstallLocation) {
        Copy-Item "$PSScriptRoot\deployment.config" "$location\lib\" -force -ErrorAction SilentlyContinue
    }

}

Function Export-CPOF {
    if (Get-Item HKLM:\SOFTWARE\JavaSoft\Prefs\CPOF -ErrorAction SilentlyContinue) {
        Write-Log "Exporting CPOF Configurations"
        start-process reg -ArgumentList "export HKEY_LOCAL_MACHINE\software\javasoft\prefs\cpof $psscriptroot\export.reg"
        start-process reg -ArgumentList "export HKEY_LOCAL_MACHINE\software\wow6432node\javasoft\prefs\cpof $psscriptroot\export64.reg"
    }
}

Function Import-CPOF {
    if (Test-Path $psscriptroot\export.reg) {
        start-process reg -ArgumentList "import $psscriptroot\export.reg"
        start-process reg -ArgumentList "import $psscriptroot\export64.reg"
    }
}


#endregion

#region Custom Adobe Acrobat Functions
Function Uninstall-AdobeAcrobat {
    Write-Log "Uninstalling using the Adobe AcroCleaner Tool (XI)"
    # Product Parameter Options
    # Product=0 - Adobe Acrobat
    # Product=1 - Adobe Reader
            
    # Execute the  Adobe AcroCleaner Tool
    $Results = Start-Process "$psscriptroot\AdbeArCleaner_v2.exe" -ArgumentList "/Silent /Product=0" -Wait -NoNewWindow -PassThru

    # Check the Status
    $exitcode = $results.ExitCode
    If ($exitcode -eq 0 -or $exitcode -eq 1707 -or $exitcode -eq 3010) {
        Write-Log "Uninstall succeeded with exit code: $exitcode. No reboot required"
    }
    elseif ($exitcode -eq 1641) {
        write-log "Uninstall succeeded with exit code: $exitcode. A reboot is required."
    }
    else {
        Write-Log "Uninstall failed with exit code: $exitcode"
    }
}
Function Uninstall-AdobeAcrobatDC {
    Write-Log "Uninstalling using the Adobe AcroCleaner Tool (DC)"
    # Product Parameter Options
    # Product=0 - Adobe Acrobat
    # Product=1 - Adobe Reader
            
    # Execute the  Adobe AcroCleaner Tool
    $Results = Start-Process "cmd" -ArgumentList "/c $psscriptroot\AdobeAcroCleaner_DC2015.exe /Silent /Product=0" -Wait -NoNewWindow -PassThru

    # Check the Status
    $exitcode = $results.ExitCode
    If ($exitcode -eq 0 -or $exitcode -eq 1707 -or $exitcode -eq 3010) {
        Write-Log "Uninstall succeeded with exit code: $exitcode. No reboot required"
    }
    elseif ($exitcode -eq 1641) {
        write-log "Uninstall succeeded with exit code: $exitcode. A reboot is required."
    }
    elseif (!(Get-InstalledSoftware "Adobe Acrobat DC")) {
        Write-Log "Uninstall succeeded with exit code: $exitcode."
    }
    else {
        Write-Log "Uninstall failed with exit code: $exitcode"
    }
}

Function Uninstall-AdobeReaderDC {
    Write-Log "Uninstalling using the Adobe AcroCleaner Tool (DC)"
    # Product Parameter Options
    # Product=0 - Adobe Acrobat
    # Product=1 - Adobe Reader
            
    # Execute the  Adobe AcroCleaner Tool
    $Results = Start-Process "cmd" -ArgumentList "/c $psscriptroot\AdobeAcroCleaner_DC2015.exe /Silent /Product=1" -Wait -NoNewWindow -PassThru

    # Check the Status
    $exitcode = $results.ExitCode
    If ($exitcode -eq 0 -or $exitcode -eq 1707 -or $exitcode -eq 3010) {
        Write-Log "Uninstall succeeded with exit code: $exitcode. No reboot required"
    }
    elseif ($exitcode -eq 1641) {
        write-log "Uninstall succeeded with exit code: $exitcode. A reboot is required."
    }
    elseif (!(Get-InstalledSoftware "Adobe Acrobat DC")) {
        Write-Log "Uninstall succeeded with exit code: $exitcode."
    }
    else {
        Write-Log "Uninstall failed with exit code: $exitcode"
    }
}
#endregion

#region Custom Cisco Jabber Functions
Function Uninstall-CiscoJabber {
    # Uninstall Cisco Jabber (used to prevent removal Cisco Jabber for Telepresence)
    Write-Log "--Uninstallation Begin"
    $InstalledSoftware = Get-InstalledSoftware -softwarename "Cisco Jabber"
    ForEach ($software in $installedsoftware) {
        if ($software.softwarename -eq "Cisco Jabber") {
            $version = $software.Version
            $name = $Software.SoftwareName
            $strUninstall = $software.uninstallstring
            Write-Log "The current version of Cisco Jabber installed is $version"
            $results = Start-Process cmd -argumentlist "/c $strUninstall" -PassThru -NoNewWindow -wait
            Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
            $exitcode = $results.ExitCode
            Write-Log "Uninstallation of Cisco Jabber version $version returned exit code $exitcode"
        }
    }
    Write-Log "--Uninstallation End"
}

#endregion

#region Custom Cisco AnyConnect Functions

Function Uninstall-CiscoAnyConnectClient {
    Write-Log "--Uninstallation Begin"
    $InstalledSoftware = Get-InstalledSoftware -softwarename "Cisco AnyConnect" | Where-Object SoftwareName -NotMatch "Cisco AnyConnect [sd][ei][ca]"
    ForEach ($Software in $InstalledSoftware) {
        $version = $software.Version
        $name = $Software.SoftwareName
        $strUninstall = $software.uninstallstring
        Write-Log "The current version of $($Software.SoftwareName) installed is $($Software.version)"
        $results = Start-Process cmd -argumentlist "/c $strUninstall" -PassThru -NoNewWindow -wait
        Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
        $exitcode = $results.ExitCode
        Write-Log "Uninstallation of $($Software.SoftwareName) version $($Software.version) returned exit code $exitcode"
    }

    $InstalledSoftware = Get-InstalledSoftware -softwarename "Cisco AnyConnect Secure Mobility Client" | Select -First 1
    ForEach ($Software in $InstalledSoftware) {
        $version = $software.Version
        $name = $Software.SoftwareName
        $strUninstall = $software.uninstallstring
        Write-Log "The current version of $($Software.SoftwareName) installed is $($Software.version)"
        $results = Start-Process cmd -argumentlist "/c $strUninstall" -PassThru -NoNewWindow -wait
        Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
        $exitcode = $results.ExitCode
        Write-Log "Uninstallation of $($Software.SoftwareName) version $($Software.version) returned exit code $exitcode"
    }

    $InstalledSoftware = Get-InstalledSoftware -softwarename "Cisco AnyConnect"
    ForEach ($Software in $InstalledSoftware) {
        $version = $software.Version
        $name = $Software.SoftwareName
        $strUninstall = $software.uninstallstring
        Write-Log "The current version of $($Software.SoftwareName) installed is $($Software.version)"
        $results = Start-Process cmd -argumentlist "/c $strUninstall" -PassThru -NoNewWindow -wait
        Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
        $exitcode = $results.ExitCode
        Write-Log "Uninstallation of $($Software.SoftwareName) version $($Software.version) returned exit code $exitcode"
    }
    Write-Log "--Uninstallation End"
}

Function Start-AnyConnectConfiguration {
    Write-Log "--Configuration Begin"
    $RAVPNProfile = (Get-ItemProperty HKLM:\SOFTWARE\AGMProgram\Build -Name RAVPNProfile -ErrorAction SilentlyContinue).RAVPNProfile
    $Gateways = @{
        "EUR"  = "0.0.0.0    fqdn     `# RAVPN EUR Gateway"
        "EUR2" = "0.0.0.0    fqdn    `# RAVPN EUR2 Gateway"
        "AFR"  = "0.0.0.0    fqdn     `# RAVPN AFRICOM Gateway"
    }
    $Change = $false
    $HostFilePath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $HostFile = Get-Content $HostFilePath -ErrorAction Stop
    If ((Get-WmiObject -Class Win32_ComputerSystem).Domain -match "USAFRICOM" -or $RAVPNProfile -match "^AFN$") {
        If (!($HostFile | Select-String -SimpleMatch $Gateways.AFR)) {
            If ($HostFile | Select-String -SimpleMatch $Gateways.AFR.Split(" ")[0]) {
                $HostFile = $HostFile | Select-String -Pattern $Gateways.AFR.Split(" ")[0] -NotMatch
                $HostFile += $Gateways.AFR
                $Change = $true
            }
            Else {
                $HostFile += $Gateways.AFR
                $Change = $true
            }
        }
    }
    ElseIf ((Get-WmiObject -Class Win32_ComputerSystem).Domain -match "EUR" -or $RAVPNProfile -match "^EUR") {
        If (!($HostFile | Select-String -SimpleMatch $Gateways.EUR)) {
            If ($HostFile | Select-String -SimpleMatch $Gateways.EUR.Split(" ")[0]) {
                $HostFile = $HostFile | Select-String -Pattern $Gateways.EUR.Split(" ")[0] -NotMatch
                $HostFile += $Gateways.EUR
                $Change = $true
            }
            Else {
                $HostFile += $Gateways.EUR
                $Change = $true
            }
        }
        If (!($HostFile | Select-String -SimpleMatch $Gateways.EUR2)) {
            If ($HostFile | Select-String -SimpleMatch $Gateways.EUR2.Split(" ")[0]) {
                $HostFile = $HostFile | Select-String -Pattern $Gateways.EUR2.Split(" ")[0] -NotMatch
                $HostFile += $Gateways.EUR2
                $Change = $true
            }
            Else {
                $HostFile += $Gateways.EUR2
                $Change = $true
            }
        }
        If (Test-Path "$env:ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\ISE Posture\") {
            Copy-Item -Path "$PSScriptRoot\Profiles\ISE Posture\ISEPostureCFG.xml" -Destination "$env:ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\ISE Posture\" -Force | Out-Null
        }
    }
    If ($Change -eq $true) {
        $HostFile | Out-File $HostFilePath -Encoding ascii -Force
    }
    Copy-Item -Path "$PSScriptRoot\Source\AnyConnectLocalPolicy.xml" -Destination "$env:ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\AnyConnectLocalPolicy.xml" -Force

    Write-Log "--Configuration End"
}


#endregion

#region Custom ActivClient Functions

Function Start-ACConfiguration {
    #Apply OS Patch if necessary
    $OSVersion = (Get-WmiObject win32_operatingsystem).version
    if ($OSVersion -match "6.3") {
        Write-Log "Applying KB2999226"
        start-process dism.exe -ArgumentList "/online /add-package /packagepath:$psscriptroot\Updates\Windows8.1-KB2999226-x64.cab" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
    }
    elseif ($OSVersion -match "6.2") {
        Write-Log "Applying KB2999226"
        start-process dism.exe -ArgumentList "/online /add-package /packagepath:$psscriptroot\Updates\Windows8-RT-KB2999226-x64.cab" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
    }
    elseif ($OSVersion -match "6.1") {
        Write-Log "Applying KB2999226"
        start-process dism.exe -ArgumentList "/online /add-package /packagepath:$psscriptroot\Updates\Windows6.1-KB2999226-x86.cab" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
    }

    Write-Log "Importing Certificates"
    #Import Certificates
    start-process certutil -argumentlist "-addstore -f `"TrustedPublisher`" `"$psscriptroot\Certs\HID_Global_Corporation.cer`"" -WindowStyle Hidden -wait
    start-process certutil -argumentlist "-addstore -f `"TrustedPublisher`" `"$psscriptroot\Certs\HID_Global_Corporation_205.cer`"" -WindowStyle Hidden -wait
    start-process certutil -argumentlist "-addstore -f `"CA`" `"$psscriptroot\Certs\Symantec_Class_3_SHA256_Code_Signing_CA_G2.cer`"" -WindowStyle Hidden -Wait
    start-process certutil -argumentlist "-addstore -f `"CA`" `"$psscriptroot\Certs\DigiCert_Code_Signing_CA.cer`"" -WindowStyle Hidden -Wait
    start-process certutil -argumentlist "-addstore -f `"Root`" `"$psscriptroot\Certs\VeriSign_Universal_Root_Certification_Authority.cer`"" -WindowStyle Hidden -Wait
    start-process certutil -argumentlist "-addstore -f `"Root`" `"$psscriptroot\Certs\DigiCert_Root_CA.cer`"" -WindowStyle Hidden -Wait


    Write-Log "Applying Group Policy"
    #Copy Group Policy Templates / Language Files
    copy-item $psscriptroot\ADMl\* $env:SystemRoot\PolicyDefinitions\en-US\
    copy-item $psscriptroot\ADMx\* $env:SystemRoot\PolicyDefinitions\

    #Apply Group Policy Settings
    start-process $psscriptroot\LGPO\LGPO.exe -ArgumentList "/m $psscriptroot\LGPO\registry.pol" -WindowStyle Hidden

}

#endregion

#region Custom Vidyo Functions
Function Set-VidyoRegistry {
    $domain = (Get-WmiObject win32_computersystem).domain
    if ($domain -match "domain removed") {
        $portal = "domain removed"
    }
    else {
        $portal = "domain removed"
    }
        
    New-PSDrive -Name HKU -Root HKEY_USERS -PSProvider Registry
    # Regex pattern for SIDs
    $PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
 
    # Get Username, SID, and location of ntuser.dat for all users
    $ProfileList = gp 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object { $_.PSChildName -match $PatternSID } | 
    Select  @{name = "SID"; expression = { $_.PSChildName } }, 
    @{name = "UserHive"; expression = { "$($_.ProfileImagePath)\ntuser.dat" } }, 
    @{name = "Username"; expression = { $_.ProfileImagePath -replace '^(.*[\\\/])', '' } }

    $ProfileList += [pscustomobject]@{'SID' = 'default'; "userhive" = 'C:\users\default\NTUSER.DAT'; 'username' = 'default' }

    $ProfileList = $ProfileList | ? username -ne "defaultuser0"

    # Get all user SIDs found in HKEY_USERS (ntuder.dat files that are loaded)
    $LoadedHives = gci Registry::HKEY_USERS | ? { $_.PSChildname -match $PatternSID } | Select @{name = "SID"; expression = { $_.PSChildName } }
 
    # Get all users that are not currently logged
    $UnloadedHives = Compare-Object $ProfileList.SID $LoadedHives.SID | Select @{name = "SID"; expression = { $_.InputObject } }, UserHive, Username
 
    # Loop through each profile on the machine
    Foreach ($item in $ProfileList) {
        $sid = $item.SID
        $userhive = $item.userhive
        # Load User ntuser.dat if it's not already loaded
        IF ($item.SID -in $UnloadedHives.SID) {
            reg load HKU\$sid $userhive | Out-Null
        }
        $sid = $item.SID

        #region Registry Keys

        "{0}" -f $($item.Username) | Write-Output
        if (Test-Path hku:\$sid\software\vidyo) {
            Set-ItemProperty "hku:\$sid\software\vidyo\vidyo desktop\2.0" -Name "Portal Address" -Value "$portal/services/"
            Set-ItemProperty "hku:\$sid\software\vidyo\vidyo desktop\2.0" -Name "Portal History" -Value "portal=$portal&un=null`r`n"
            Set-ItemProperty "hku:\$sid\software\vidyo\vidyodesktop3\external" -name "CacPortals" -Value "$portal"
        }
        else {
            New-Item "hku:\$sid\software\vidyo\vidyo desktop\2.0" -Force
            New-ItemProperty "hku:\$sid\software\vidyo\vidyo desktop\2.0" -Name "Portal Address" -Value "$portal/services/" -PropertyType string
            New-ItemProperty "hku:\$sid\software\vidyo\vidyo desktop\2.0" -Name "Portal History" -Value "portal=$portal&un=null`r`n" -PropertyType multistring
            New-Item "hku:\$sid\software\vidyo\vidyodesktop3\external" -Force
            New-ItemProperty "hku:\$sid\software\vidyo\vidyodesktop3\external" -name "CacPortals" -Value "$portal" -PropertyType string

        }

        #endregion    

        # Unload ntuser.dat        
        IF ($item.SID -in $UnloadedHives.SID) {
            ### Garbage collection and closing of ntuser.dat ###
            [gc]::Collect()
            reg unload HKU\$($Item.SID) | Out-Null
        }
    }

    Remove-PSDrive HKU
}
#endregion
#Remove VC++ paramatize version and bitness
Function Uninstall-VC {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('2012', 'v14', '2015', '2022')]
        [String]$VcVersion,
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('x64', 'x86')]
        [String]$VcBitness,
        [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true)]
        [string]$SoftwareName = "Microsoft Visual C++ $VcVersion Redistributable ($VcBitness)"

    )
    Begin {
        If (-not([String]::IsNullOrWhiteSpace($SoftwareName))) {
            $Software = Get-InstalledSoftware -SoftwareName "$SoftwareName"
        }
    }
    Process {
        Write-Log "--Uninstallation Begin"
        If ($Software.SoftwareName -like "*$SoftwareName*") {
            Write-Log "The current version of $($Software.SoftwareName) installed is $($Software.Version)"
            $Result = Start-Process cmd -ArgumentList "/c `"$($Software.UninstallExe)`" /uninstall /S" -PassThru -NoNewWindow -Wait
            Do { Start-Sleep -Milliseconds 500 } Until($Result.HasExited)
            Write-Log "Uninstallation of $($Software.SoftwareName) version $($Software.Version) returned exit code $($Result.ExitCode)"
        }
        Else {
            Write-Log "Software $SoftwareName not found"
        }
    }
    End {
        Write-Log "--Uninstallation End"
    }
}
#endregion

#region Microsoft Teams Functions

Function Uninstall-Teams {
    #region machine Stuff
    Uninstall-Software $global:SoftwareName
    If (Get-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\MS Teams*") {
        Get-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\MS Teams*" | Remove-Item -Recurse -Force
    }

    #endregion

    #region user stuff
    If (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue) {

        Remove-PSDrive -Name HKU | Out-Null
    }
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
    $RegAllUsers = (Get-ChildItem -Path HKU:\ | Where-Object Name -Match "^HKEY_USERS\\s-1-5-21-\d+-\d+-\d+-\d+$").Name | ForEach-Object { $_.Split("\", 2)[-1] }
    Foreach ($REGUser in $RegAllUsers) {

        Remove-ItemProperty "HKU:\$REGUser\Software\Microsoft\Office\Teams\" -Name PreventInstallationFromMsi -Force -ErrorAction SilentlyContinue
    }
    Remove-PSDrive HKU
        
    $defaultffprofile = "[Profile0]
        Name=default
        IsRelative=1
        Path=Profiles/NPS.DEFAULT
        Default=1"

    $PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
 
    # Get Username, SID, and location of ntuser.dat for all users
    $ProfileList = (gp 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object { $_.PSChildName -match $PatternSID } | 
        Select  @{n = "Profile"; e = { $_.ProfileImagePath } }).profile

    $ProfileList += 'C:\users\default'

    $ProfileList = $ProfileList | ? { $_ -notmatch "defaultuser0" }

    foreach ($profile in $ProfileList) {
        if (Test-Path "$profile\AppData\Local\Microsoft\Teams\Current\Teams.exe") {
            Try {                    
                $result = Start-Process "$profile\AppData\Local\Microsoft\Teams\Update.exe" -ArgumentList "--uninstall /s" -PassThru -Wait
            }
            Catch {}
        }
        Remove-Item "$profile\AppData\Local\Microsoft\Teams" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$profile\AppData\Roaming\Microsoft\Teams" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$profile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Teams.lnk" -Force -ErrorAction SilentlyContinue
        Remove-Item "$profile\Desktop\Microsoft Teams.lnk" -Force -ErrorAction SilentlyContinue
    }

    #endregion

    Write-Log " --Microsoft Teams Uninstallation Tasks End"


} 

Function Start-Teams {
    Write-Log "Staring Task configuration"
    $users = (Get-WmiObject win32_Process | ? Name -EQ "Explorer.exe" -ErrorAction SilentlyContinue).GetOwner().User

    if ($users -ne $null) {
        Foreach ($user in $users) {
            $action = New-ScheduledTaskAction -Execute "Teams.exe" -WorkingDirectory "${env:ProgramFiles(x86)}\Teams Installer"
            Register-ScheduledTask -TaskName "StartTeams" -Action $action -Description "Installs Teams on user Profile" -User ("NPS\" + $user)
            Start-ScheduledTask -TaskName "StartTeams"
            Start-Sleep 15
            Unregister-ScheduledTask -TaskName "StartTeams" -confirm:$false
        }
    }
}

#endregion

#region Techsmith SnagIt Fuctions

Function Uninstall-SnagIt {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 1)]
        [string]$SoftwareName = "Snagit"
    )
    Write-Log "--Uninstallation Begin"
    $InstalledSoftware = Get-InstalledSoftware -softwarename "$SoftwareName"
    ForEach ($software in $installedsoftware) {
        if ($software.softwarename -like "*$SoftwareName*") {
            $version = $software.Version
            $name = $Software.SoftwareName
            $strUninstall = $software.uninstallstring + "TSC_DATA_STORE=0"
            Write-Log "The current version of $SoftwareName installed is $version"
            $results = Start-Process cmd -argumentlist "/c $strUninstall" -PassThru -NoNewWindow -wait
            Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
            $exitcode = $results.ExitCode
            Write-Log "Uninstallation of $SoftwareName version $version returned exit code $exitcode"
        }
    }
    Write-Log "--Uninstallation End"
}
#endregion

#region Avaya

Function Start-Avaya1XConfiguration {

    Write-Log "Starting Avaya one-X Communicator Configuration"
    # Set Config Source and destination paths
    $ConfigFile = (Get-Item -Path $PSScriptRoot\* -Filter 'config.xml').FullName
    $Destination = 'AppData\Roaming\Avaya\Avaya one-X Communicator'
    # Set SID Pattern to search
    $PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
    # Get Username, SID, and location of ntuser.dat for all users
    $ProfileList = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object { $_.PSChildName -match $PatternSID } | Select-Object  @{n = "Profile"; e = { $_.ProfileImagePath } }).profile
    $ProfileList += 'C:\users\default'
    # Copy Config file to each profile
    Foreach ($Profile in $ProfileList) {

        If (Test-Path "$Profile\$Destination\config.xml" -ErrorAction SilentlyContinue) {

            Write-Log "Configuration already exists for $($Profile.Split("\")[-1]), updating."
            Copy-Item $ConfigFile "$Profile\$Destination\config.xml" -Force -ErrorAction SilentlyContinue
        }
        Else {

            Write-Log "No profile exists for $($Profile.Split("\")[-1]), creating.."
            New-Item "$Profile\$Destination" -ItemType Directory -Force
            Copy-Item $ConfigFile "$Profile\$Destination\config.xml" -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Log "--Configuration Complete"
}

#endregion

#region Keepass

Function Uninstall-KeePass {
    Write-Log "--Uninstallation Begin"
    $InstalledSoftware = Get-InstalledSoftware -softwarename "KeePass"
    ForEach ($software in $installedsoftware) {
        if ($software.softwarename -like "*KeePass*") {
            $version = $software.Version
            $name = $Software.SoftwareName
            $strUninstall = $software.uninstallstring
            Write-Log "The current version of $SoftwareName installed is $version"
            If ($strUninstall -match "/S$") { $strUninstall = $strUninstall -replace "/S", "/Silent" }
            $results = Start-Process cmd -argumentlist "/c $strUninstall" -PassThru -NoNewWindow -wait
            Do { Start-Sleep -Milliseconds 500 } until ($results.HasExited)
            $exitcode = $results.ExitCode
            Write-Log "Uninstallation of $Name version $version returned exit code $exitcode"
        }
    }
    Write-Log "--Uninstallation End"
}

Function Start-KeePassConfiguration {
    Write-Log "-KeePass configuration Begin"
    Copy-Item $PSScriptRoot\* -Filter "*.xml" -Force ${env:ProgramFiles(x86)}\KeePass2x\
    Copy-Item $PSScriptRoot\* -Filter "*.plgx" ${env:ProgramFiles(x86)}\KeePass2x\Plugins -Force
    Write-Log "-KeePass configuration End"
}

#endregion

#region BigFix

Function Start-BigFixClientCleanup {
    Write-Log "-BigFix cleanup Begin"
    Remove-Item "$env:ProgramW6432\BigFix Enterprise\BES Client\" -Recurse -ErrorAction SilentlyContinue
    Remove-Item "${env:ProgramFiles(x86)}\BigFix Enterprise\BES Client\" -Recurse -ErrorAction SilentlyContinue
    Remove-Item HKLM:\SOFTWARE\BigFix -Recurse -ErrorAction SilentlyContinue
    Remove-Item HKLM:\SOFTWARE\WOW6432Node\BigFix -Recurse -ErrorAction SilentlyContinue
    Write-Log "-BigFix Cleanup End"
}

#endregion

#region Park Icon

Function Start-SDIIcon {
    Write-Log "Staring Task configuration"
    $users = (Get-WmiObject win32_Process | Where-Object Name -EQ "Explorer.exe" -ErrorAction SilentlyContinue).GetOwner().User

    if ($users -ne $null) {
        Foreach ($user in $users) {
            $action = New-ScheduledTaskAction -Execute "StartSDIIcon.vbs" -WorkingDirectory "$env:ProgramW6432\NPS\Standard Desktop Information Icon"
            Register-ScheduledTask -TaskName "StartIcon" -Action $action -Description "Starts the Standard Desktop Information Icon on user profile" -User ("NPS\" + $user)
            Start-ScheduledTask -TaskName "StartIcon"
            Start-Sleep 15
            Unregister-ScheduledTask -TaskName "StartIcon" -confirm:$false
        }
    }
}


#endregion

#region module exports
Export-ModuleMember -Variable $script:LogFolderName -ErrorAction SilentlyContinue 
Export-ModuleMember -Variable $script:LogPath -ErrorAction SilentlyContinue
Export-ModuleMember -Variable $script:quote -ErrorAction SilentlyContinue

Export-ModuleMember -Function Get-InstalledSoftware
Export-ModuleMember -Function Uninstall-Software
Export-ModuleMember -Function Install-Software
Export-ModuleMember -Function Write-Log
Export-ModuleMember -Function Write-ScriptErrors
Export-ModuleMember -Function Import-LocalPolicy
Export-ModuleMember -Function Get-CNDistinguishedName
Export-ModuleMember -Function Get-CNGroupMemberships
Export-ModuleMember -Function Get-UNDistinguishedName
Export-ModuleMember -Function Get-UNGroupMemberships
Export-ModuleMember -Function Set-Tattoo    

Export-ModuleMember -Function Close-RForWindows
Export-ModuleMember -Function Close-ShareX
Export-ModuleMember -Function Close-VSCode
Export-ModuleMember -Function Close-DellCommandUpdate
Export-ModuleMember -Function Close-AtHoc
Export-ModuleMember -Function Close-IE
Export-ModuleMember -Function Close-Firefox
Export-ModuleMember -Function Close-Chrome
Export-ModuleMember -Function Close-msiexec
Export-ModuleMember -Function Close-Java
Export-ModuleMember -Function Close-AdobeAcrobat
Export-ModuleMember -Function Close-Outlook
Export-ModuleMember -Function Close-Acad
Export-ModuleMember -Function Close-PDapp
Export-ModuleMember -Function Close-CreativeCloud
Export-ModuleMember -Function Close-Project
Export-ModuleMember -Function Close-Access
Export-ModuleMember -Function Close-Powerpnt
Export-ModuleMember -Function Close-Excel
Export-ModuleMember -Function Close-Word
Export-ModuleMember -Function Close-SnagIt

Export-ModuleMember -Function Uninstall-RForWindows
Export-ModuleMember -Function Uninstall-VSCode
Export-ModuleMember -Function Uninstall-Git
Export-ModuleMember -Function Set-DellBIosUpdate
Export-ModuleMember -Function Start-ACConfiguration
Export-ModuleMember -Function Start-FirefoxConfiguration
Export-ModuleMember -Function Uninstall-CiscoAnyConnectClient
Export-ModuleMember -Function Start-AnyConnectConfiguration
Export-ModuleMember -Function Uninstall-Chrome
Export-ModuleMember -Function Disable-ChromeUpdate
Export-ModuleMember -Function Start-ChromeCleanup
Export-ModuleMember -Function uninstall-Flash
Export-ModuleMember -Function Disable-FlashAutoUpdate
Export-ModuleMember -Function Set-JavaExceptionSites
Export-ModuleMember -Function Copy-JavaConfiguration
Export-ModuleMember -Function Uninstall-AdobeAcrobat
Export-ModuleMember -Function Uninstall-AdobeAcrobatDC
Export-ModuleMember -Function Uninstall-AdobeReaderDC
Export-ModuleMember -Function Start-AdobeCleanup
Export-ModuleMember -Function Export-CPOF
Export-ModuleMember -Function Import-CPOF
Export-ModuleMember -Function Uninstall-CiscoJabber
Export-ModuleMember -Function Disable-ChromeUpdate
Export-ModuleMember -Function Set-VidyoRegistry
Export-ModuleMember -Function Uninstall-Teams
Export-ModuleMember -Function Start-Teams
Export-ModuleMember -Function Uninstall-SnagIt
Export-ModuleMember -Function Start-Avaya1XConfiguration
Export-ModuleMember -Function Uninstall-KeePass
Export-ModuleMember -Function Start-KeePassConfiguration
Export-ModuleMember -Function Start-BigFixClientCleanup
Export-ModuleMember -Function Start-SDIIcon
Export-ModuleMember -Function Uninstall-Mark43Cad
Export-ModuleMember -Function Remove-NotepadPlusPlusUpdater
Export-ModuleMember -Function Remove-NppConfigAllUsers
Export-ModuleMember -Function Remove-RootCertificate
Export-ModuleMember -Function Uninstall-VC   
Export-ModuleMember -Function Set-MeridianBCRegKey
#Export-ModuleMember -Function get-SoftwareInstalledBool
#endregion

