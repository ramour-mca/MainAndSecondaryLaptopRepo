@echo off
REM ================================================================
REM General About Section
REM ================================================================
REM Use this script template as a frontend to launch a powershell file with parameters.
REM This script will also pass on any exit code from the powershell script and exit with that exit code
REM 
REM Author:		OCIO SCCM Team
REM Revision:	08/10/2017 - Initial Build
REM ================================================================

REM ================================================================
REM Script Specific Help Section
REM ================================================================
REM None
REM
REM ================================================================

REM ================================================================
REM Set Variables
REM ================================================================
REM Specify the Full name of the script, including the extension
REM Set ScriptFile=installer.ps1
Set ScriptFile=Install.ps1
REM
REM Specify the Full Path of the Log Directory (for install/uninstall logs)
REM Set LogDir=C:\SoftwareLogs
Set LogDir=C:\SoftwareLogs
REM ================================================================

REM ================================================================
REM DO NOT EDIT BELOW THIS LINE
REM ================================================================

REM Expand variables at execution time rather than at parse time
setlocal enabledelayedexpansion

REM Enable Command extensions
setlocal enableextensions

REM Find out if the system is x86 or x64
reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OS=32BIT || set OS=64BIT

REM Make sure the Log Directory is created.  If not, create it.
if not exist "%LogDir%" md "%LogDir%"

REM We want to run 64bit powershell.exe if the system is 64bit.  Launch powershell script with arguments
if %OS%==64BIT (
	if %PROCESSOR_ARCHITECTURE%==AMD64 (
		%windir%\system32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0%ScriptFile%' %*"
		Exit /b !errorlevel!
	) else (
		%windir%\sysnative\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0%ScriptFile%' %*"
		Exit /b !errorlevel!
	)
) else (
	%windir%\system32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0%ScriptFile%' %*"
	Exit /b !errorlevel!
)