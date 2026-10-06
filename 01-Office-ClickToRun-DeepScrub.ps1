<#
.SYNOPSIS
    Deep clean and uninstaller script for Microsoft Office and Click-to-Run environments.
.DESCRIPTION
    Performs a complete administrative scrub of Microsoft Office installations:
    1. Forcefully terminates stuck Office and Click-to-Run processes.
    2. Stops, disables, and deletes associated Windows services.
    3. Unregisters automated update scheduled tasks.
    4. Purges corrupt registry hives across standard and Wow6432Node paths.
    5. Cleans remaining installation directories and temporary files.
    Optimized for silent execution via RMM platforms (Action1, Atera).
.NOTES
    Author: Iván Felipe Rodríguez C.
    Version: 1.0
#>

#Requires -RunAsAdministrator

Write-Output "[+] Starting deep scrub of Microsoft Office environment..."

# 1. Terminate active Office processes
Write-Output "[+] Terminating active processes in memory..."
$Procesos = @(
    "officeclicktorun", "setup", "winword", "excel", "powerpnt", 
    "outlook", "onenote", "msaccess", "communicator", "lync", "teams"
)

foreach ($proc in $Procesos) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# 2. Stop, disable, and remove system services
Write-Output "[+] Removing system services..."
$Servicios = @("ClickToRunSvc", "OfficeSvc")

foreach ($srv in $Servicios) {
    if (Get-Service -Name $srv -ErrorAction SilentlyContinue) {
        Stop-Service -Name $srv -Force -ErrorAction SilentlyContinue
        Set-Service -Name $srv -StartupType Disabled -ErrorAction SilentlyContinue
        sc.exe delete $srv | Out-Null
    }
}

# 3. Unregister Click-to-Run scheduled tasks
Write-Output "[+] Unregistering update scheduled tasks..."
Get-ScheduledTask -TaskPath "\Microsoft\Office\*" -ErrorAction SilentlyContinue | 
    Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

# 4. Purge Office registry entries
Write-Output "[+] Cleaning Office registry keys..."
$RamasRegistro = @(
    "HKLM:\SOFTWARE\Microsoft\Office",
    "HKLM:\SOFTWARE\Microsoft\ClickToRun",
    "HKLM:\SOFTWARE\Microsoft\AppVISV",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\ClickToRun",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Office16*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Office16*"
)

foreach ($reg in $RamasRegistro) {
    if (Test-Path $reg) {
        Remove-Item -Path $reg -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

# 5. Remove residual installation directories and temporary caches
Write-Output "[+] Purging residual installation directories and temp cache..."
$CarpetasOffice = @(
    "${env:ProgramFiles}\Microsoft Office",
    "${env:ProgramFiles(x86)}\Microsoft Office",
    "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun",
    "${env:ProgramData}\Microsoft\ClickToRun",
    "${env:ProgramData}\Microsoft\Office",
    "${env:SystemRoot}\Temp\*",
    "$env:LOCALAPPDATA\Microsoft\Office"
)

foreach ($carpeta in $CarpetasOffice) {
    if (Test-Path $carpeta) {
        Remove-Item -Path $carpeta -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

Write-Output "[+] Deep cleanup completed successfully. System cleared of Office residues."
exit 0
