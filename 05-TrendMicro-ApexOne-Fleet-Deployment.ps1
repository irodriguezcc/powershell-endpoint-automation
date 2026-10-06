<#
.SYNOPSIS
    Automated fleet-wide detection, staging, and silent deployment of Trend Micro Apex One Security Agent.
.DESCRIPTION
    Engineered for mass rollout across 300+ enterprise endpoints via RMM (Action1 / Atera):
    1. Triple-Factor Pre-Flight Check:
       - Registry inspection across 32-bit and 64-bit Uninstall hives.
       - Verification of core Trend Micro security services (ntrtscan, OfficeScanAgent, TmListen, PccNTMon).
       - File system validation in Program Files and Program Files (x86).
    2. Dynamic SMB Mount: Mounts isolated temporary PSDrive (Z:) using secure network credentials.
    3. Local Staging: Copies deployment packages to local staging path to prevent network-drop corruption.
    4. Silent Execution: Dispatches unattended installation routines for MSI (/qn) or vendor EXE (-s).
    5. Guaranteed Teardown: Unmounts PSDrive session and wipes local temporary payloads in Finally block.
.NOTES
    Author: Iván Felipe Rodríguez C.
    Version: 1.2
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [string]$ServerShare   = "\\10.0.0.10\SecurityDeployments",
    [string]$SubFolder     = "EndpointSecurity\ApexOne\Packages",
    [string]$DomainUser    = "DOMAIN\DeploymentService",
    [string]$PlainPassword = "EncryptedSecretKey*",
    [string]$StagingPath   = "$env:SystemRoot\Temp\ApexOneDeploymentStage"
)

# =====================================================================
# 1. TRIPLE-FACTOR IDEMPOTENCY CHECK (APEX ONE AGENT)
# =====================================================================
Write-Output "[+] Validating endpoint security agent status..."

# A. Registry Scan (32-bit & 64-bit hives)
$ApexRegistry = Get-ItemProperty @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
) -ErrorAction SilentlyContinue | Where-Object { 
    $_.DisplayName -like "*Apex One Security Agent*" -or $_.DisplayName -like "*OfficeScan Agent*" 
}

# B. Core Security Services Verification
$ApexServices = Get-Service -Name "ntrtscan", "OfficeScanAgent", "TmListen", "PccNTMon" -ErrorAction SilentlyContinue

# C. Canonical File System Paths
$PathApex1 = Test-Path "${env:ProgramFiles(x86)}\Trend Micro\Apex One Security Agent"
$PathApex2 = Test-Path "${env:ProgramFiles}\Trend Micro\Apex One Security Agent"
$PathApex3 = Test-Path "${env:ProgramFiles(x86)}\Trend Micro\OfficeScan Client"

# Evaluation gate
if ($ApexRegistry -or $ApexServices -or$PathApex1 -or $PathApex2 -or$PathApex3) {
    Write-Output "[!] DETECTED: Trend Micro Apex One Agent is already installed and active on this workstation."
    Write-Output "[+] Skipping installation routine to prevent service collision. Process completed successfully."
    exit 0
}

Write-Output "[+] Apex One Agent not detected. Proceeding with deployment routine..."

# =====================================================================
# 2. SECURE NETWORK AUTHENTICATION & STAGING
# =====================================================================
$DriveLetter = "Z"

try {
    Write-Output "[+] Authenticating against network deployment repository ($ServerShare)..."
    
    $secPassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force$credential  = New-Object System.Management.Automation.PSCredential ($DomainUser,$secPassword)

    # Mount temporary network PSDrive
    Write-Output "[+] Mounting secure network drive ($($DriveLetter):)..."
    New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $ServerShare -Credential$credential -ErrorAction Stop | Out-Null

    $NetworkPackagePath = Join-Path -Path "${DriveLetter}:\" -ChildPath $SubFolder

    if (-not (Test-Path -Path $NetworkPackagePath)) {
        throw "Network deployment package directory not found: $NetworkPackagePath"
    }

    # Prepare local staging cache
    if (Test-Path $StagingPath) { 
        Remove-Item -Path $StagingPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null 
    }
    New-Item -ItemType Directory -Path $StagingPath -Force | Out-Null

    # Stage payload locally
    Write-Output "[+] Transferring deployment payload to local staging environment..."
    Copy-Item -Path "$NetworkPackagePath\*" -Destination $StagingPath -Recurse -Force -ErrorAction Stop

    # =====================================================================
    # 3. LOCATE PACKAGE & DISPATCH SILENT INSTALLER
    # =====================================================================
    Write-Output "[+] Scanning staged payload for installation binaries..."
    $Installer = Get-ChildItem -Path $StagingPath -Recurse -File \vert{} Where-Object {$_.Extension -match "exe|msi" } | Select-Object -First 1

    if (-not $Installer) {
        throw "No valid .exe or .msi setup package found in staged files."
    }

    Write-Output "[+] Deploying $($Installer.Name)..."

    if ($Installer.Extension -eq ".msi") {
        $proc = Start-Process msiexec.exe -ArgumentList "/i `"$($Installer.FullName)`" /qn /norestart ALLUSERS=1" -Wait -PassThru
    } else {
        # Vendor silent switch for Trend Micro Apex One Client Setup
        $proc = Start-Process -FilePath$Installer.FullName -ArgumentList "-s" -Wait -PassThru
    }

    Write-Output "[+] Deployment execution finished with exit code: $($proc.ExitCode)"

    if ($proc.ExitCode -ne 0) {
        exit $proc.ExitCode
    }

} catch {
    Write-Error "[-] Deployment failure: $_"
    exit 1
} finally {
    # =====================================================================
    # 4. TEARDOWN & REPOSITORY CLEANUP
    # =====================================================================
    if (Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name $DriveLetter -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Output "[+] Network drive session ($($DriveLetter):) dismounted."
    }

    if (Test-Path $StagingPath) {
        Remove-Item -Path $StagingPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Output "[+] Staging cache wiped."
    }

    Write-Output "[+] Operation complete."
}
