<#
.SYNOPSIS
    Silent de-bloat, uninstallation, and policy enforcement script for Microsoft Edge and Windows Copilot.
.DESCRIPTION
    Designed for deployment via enterprise RMM (Action1 / Atera) to build lean developer workstations:
    1. Removes Copilot AppX packages across all existing and newly provisioned user profiles.
    2. Enforces Group Policy registry flags to disable Windows Copilot and hide taskbar icons.
    3. Locates and silently executes Edge uninstaller binaries (--system-level --force-uninstall).
    4. Applies enterprise EdgeUpdate blocking policies (DoNotUpdateToEdgeWithChromium and GUID lockdown).
    5. Disables residual Edge update services and background scheduled tasks.
.NOTES
    Author: Iván Felipe Rodríguez C.
    Version: 1.0
#>

#Requires -RunAsAdministrator

Write-Output "[+] Initiating workstation de-bloat routine (Edge & Copilot)..."

# =====================================================================
# 1. REMOVE AND ENFORCE POLICY BLOCK FOR MICROSOFT COPILOT
# =====================================================================
Write-Output "`n[+] Removing Microsoft Copilot AppX packages..."

# A. Remove AppX packages for all users and de-provision for future profiles
Get-AppxPackage -AllUsers *Copilot* -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -match "Copilot" } | 
    Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null

# B. Enforce policy registry hive to disable Windows Copilot
$RegCopilot = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
if (-not (Test-Path $RegCopilot)) { New-Item -Path $RegCopilot -Force | Out-Null }
Set-ItemProperty -Path $RegCopilot -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force

# C. Hide Copilot taskbar trigger button by default
$RegExplorer = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (Test-Path $RegExplorer) {
    Set-ItemProperty -Path $RegExplorer -Name "ShowCopilotButton" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
}

Write-Output "[+] Copilot packages removed and disabled via registry policy."

# =====================================================================
# 2. SILENTLY UNINSTALL MICROSOFT EDGE
# =====================================================================
Write-Output "`n[+] Scanning for Microsoft Edge installer binaries..."

$EdgeSetupPaths = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application",
    "${env:ProgramFiles}\Microsoft\Edge\Application"
)

$SetupExe =$null
foreach ($path in$EdgeSetupPaths) {
    if (Test-Path $path) {
        $found = Get-ChildItem -Path$path -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $SetupExe =$found.FullName; break }
    }
}

if ($SetupExe) {
    Write-Output "[+] Executing silent Edge uninstall routine: ($SetupExe)..."
    $proc = Start-Process -FilePath$SetupExe -ArgumentList "--uninstall --system-level --verbose-logging --force-uninstall" -Wait -PassThru
    Write-Output "[+] Uninstaller process exit code: $($proc.ExitCode)"
} else {
    Write-Output "[-] setup.exe not located. Edge may have already been uninstalled or stripped."
}

# =====================================================================
# 3. ENFORCE PERSISTENT POLICIES AGAINST EDGE REINSTALLATION
# =====================================================================
Write-Output "`n[+] Applying persistent block policies against Edge Update engine..."

# A. Official Microsoft registry flag to prevent Chromium Edge deployment
$RegEdgeUpdate = "HKLM:\SOFTWARE\Microsoft\EdgeUpdate"
if (-not (Test-Path $RegEdgeUpdate)) { New-Item -Path $RegEdgeUpdate -Force | Out-Null }
Set-ItemProperty -Path $RegEdgeUpdate -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Type DWord -Force

# B. Policy registry rule to block Edge installer GUID
$RegEdgePolicy = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
if (-not (Test-Path $RegEdgePolicy)) { New-Item -Path $RegEdgePolicy -Force | Out-Null }
# Official Edge Runtime install GUID: 0 = Blocked
Set-ItemProperty -Path $RegEdgePolicy -Name "Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" -Value 0 -Type DWord -Force

# C. Stop and disable residual update services
$ServiciosEdge = @("edgeupdate", "edgeupdatem")
foreach ($srv in $ServiciosEdge) {
    if (Get-Service -Name $srv -ErrorAction SilentlyContinue) {
        Stop-Service -Name $srv -Force -ErrorAction SilentlyContinue
        Set-Service -Name $srv -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Output "[+] Service $srv stopped and disabled."
    }
}

# D. Disable update engine scheduled tasks
Get-ScheduledTask -TaskPath "\" -ErrorAction SilentlyContinue | 
    Where-Object { $_.TaskName -match "MicrosoftEdgeUpdate" } | 
    Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null

Write-Output "`n[+] Workstation remediation completed. Edge and Copilot removed and locked."
exit 0
