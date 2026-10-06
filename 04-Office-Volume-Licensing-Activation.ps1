<#
.SYNOPSIS
    Automated silent volume licensing injection and activation routine for Microsoft Office.
.DESCRIPTION
    Designed for fleet-wide mass deployment via RMM (Action1 / Atera) across 100+ endpoints:
    1. Dynamically detects OSPP.VBS across 64-bit and 32-bit (x86) installation architectures.
    2. Injects product key parameter via cscript.exe (/inpkey).
    3. Triggers immediate online/KMS silent activation (/act).
    4. Queries and logs licensing status diagnostic output (/dstatus).
    5. Returns structured exit codes based on activation success.
.NOTES
    Author: Iván Felipe Rodríguez C.
    Version: 1.0
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$ProductKey = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
)

Write-Output "[+] Initiating automated Office volume activation routine..."

# ---------------------------------------------------------------------
# 1. DYNAMIC OSPP.VBS ENGINE DISCOVERY
# ---------------------------------------------------------------------
$CandidatePaths = @(
    "${env:ProgramFiles}\Microsoft Office\Office16\OSPP.VBS",
    "${env:ProgramFiles(x86)}\Microsoft Office\Office16\OSPP.VBS",
    "${env:ProgramFiles}\Microsoft Office\Office15\OSPP.VBS",
    "${env:ProgramFiles(x86)}\Microsoft Office\Office15\OSPP.VBS"
)

$OsppPath =$null
foreach ($path in$CandidatePaths) {
    if (Test-Path -Path $path) {
        $OsppPath =$path
        break
    }
}

if (-not $OsppPath) {
    Write-Error "[-] OSPP.VBS script not found across standard 64-bit or 32-bit install paths."
    exit 1
}

Write-Output "[+] Located licensing engine: $OsppPath"

# ---------------------------------------------------------------------
# 2. INJECT PRODUCT KEY
# ---------------------------------------------------------------------
if ($ProductKey -and$ProductKey -ne "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX") {
    Write-Output "[+] Registering product key into licensing store..."
    $resInpKey = cscript.exe //NoLogo "$OsppPath" /inpkey:$ProductKey
    Write-Output $resInpKey
} else {
    Write-Output "[!] Default/Placeholder key detected. Skipping key injection, proceeding to trigger activation..."
}

# ---------------------------------------------------------------------
# 3. TRIGGER ACTIVATION
# ---------------------------------------------------------------------
Write-Output "`n[+] Triggering activation against licensing servers..."
$resAct = cscript.exe //NoLogo "$OsppPath" /act
Write-Output $resAct

# ---------------------------------------------------------------------
# 4. DIAGNOSTIC STATUS CHECK
# ---------------------------------------------------------------------
Write-Output "`n[+] Fetching current license status:"
$resStatus = cscript.exe //NoLogo "$OsppPath" /dstatus
Write-Output $resStatus

if ($resStatus -match "LICENSED") {
    Write-Output "`n[+] Activation confirmed: WORKSTATION IS FULLY LICENSED."
    exit 0
} else {
    Write-Output "`n[!] Warning: License state could not be verified as LICENSED. Review diagnostic output."
    exit 2
}
