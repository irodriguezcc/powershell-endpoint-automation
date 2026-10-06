<#
.SYNOPSIS
    Fault-tolerant, staged enterprise software deployment using authenticated SMB and Robocopy.
.DESCRIPTION
    Designed for silent execution across distributed fleet endpoints via RMM (Action1 / Atera):
    1. Idempotency Check: Scans registry hives and local file system to prevent duplicate installations.
    2. Network Authentication: Temporarily mounts secure enterprise share using non-persistent credentials.
    3. Resilient Local Staging: Utilizes Robocopy with retry limits (/R:3 /W:2) to mitigate transient network drops.
    4. Evaluates Robocopy bitmask exit codes (values < 8 indicate successful file transfer).
    5. Dispatches silent unattended installer (MSI or EXE) from local staging directory.
    6. Finally block guarantees cleanup of temp files and teardown of authenticated network session.
.NOTES
    Author: Iván Felipe Rodríguez C.
    Version: 1.1
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [string]$ServerShare   = "\\10.0.0.10\Deployments",
    [string]$PackageFolder = "Logistics_Planning_Suite\v26.5\install",
    [string]$DomainUser    = "DOMAIN\DeploymentService",
    [string]$SecurePass    = "EncryptedServiceSecret",
    [string]$StagingPath   = "$env:SystemRoot\Temp\SoftwareDeploymentStage"
)

# ---------------------------------------------------------------------
# 1. PRE-FLIGHT DETECTION (IDEMPOTENCE CHECK)
# ---------------------------------------------------------------------
Write-Output "[+] Checking if target application is already installed..."

$AppLocalPath = Test-Path "${env:SystemDrive}\GroundStar"
$AppRegistry  = Get-ItemProperty @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
) -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "GroundStar|Inform|GS Planning" }

if ($AppLocalPath -or$AppRegistry) {
    Write-Output "[!] Target application already detected on this workstation."
    Write-Output "[+] Skipping installation routine. Process exited successfully."
    exit 0
}

Write-Output "[+] Application not found. Proceeding with network staging..."

$FullSourcePath = Join-Path -Path $ServerShare -ChildPath$PackageFolder

try {
    # ---------------------------------------------------------------------
    # 2. AUTHENTICATE NETWORK SESSION
    # ---------------------------------------------------------------------
    Write-Output "[+] Establishing authenticated SMB session with $ServerShare..."
    
    # Tear down any stale connections first
    Start-Process -FilePath "net.exe" -ArgumentList "use `"$ServerShare`" /delete /y" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null

    # Establish clean non-persistent session
    $netAuth = Start-Process -FilePath "net.exe" -ArgumentList "use `"$ServerShare`" `"$SecurePass`" /user:`"$DomainUser`" /persistent:no" -NoNewWindow -Wait -PassThru
    
    if ($netAuth.ExitCode -ne 0) {
        throw "Failed to authenticate against network share (net.exe ExitCode: $($netAuth.ExitCode))."
    }

    if (-not (Test-Path -LiteralPath $FullSourcePath)) {
        throw "Network package path not reachable: $FullSourcePath"
    }

    # ---------------------------------------------------------------------
    # 3. PREPARE LOCAL STAGING DIRECTORY
    # ---------------------------------------------------------------------
    if (Test-Path $StagingPath) { 
        Remove-Item -Path $StagingPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null 
    }
    New-Item -ItemType Directory -Path $StagingPath -Force | Out-Null

    # ---------------------------------------------------------------------
    # 4. RESILIENT TRANSFER (ROBOCOPY)
    # ---------------------------------------------------------------------
    Write-Output "[+] Staging deployment payload locally via Robocopy (fault-tolerant transfer)..."
    # /E = recursive, /R:3 = 3 retries on network blip, /W:2 = 2s wait between retries, /NP = suppress progress noise in logs
    $procesoRobo = Start-Process -FilePath "robocopy.exe" -ArgumentList "`"$FullSourcePath`" `"$StagingPath`" /E /R:3 /W:2 /NP" -NoNewWindow -Wait -PassThru

    # In Robocopy bitmask: codes < 8 indicate successful transfer (0 = identical, 1-7 = files copied successfully)
    if ($procesoRobo.ExitCode -ge 8) {
        throw "Robocopy fatal error during transfer (ExitCode: $($procesoRobo.ExitCode))."
    }
    Write-Output "[+] Package payload successfully staged locally."

    # ---------------------------------------------------------------------
    # 5. LOCATE BINARY AND DISPATCH SILENT INSTALL
    # ---------------------------------------------------------------------
    Write-Output "[+] Scanning staged files for installer binary..."
    $Instalador = Get-ChildItem -Path $StagingPath -Recurse -File \vert{} Where-Object {$_.Extension -match "exe|msi" } | Select-Object -First 1

    if (-not $Instalador) {
        throw "No valid .exe or .msi installer located inside staged payload."
    }

    Write-Output "[+] Executable located: $($Instalador.Name). Starting silent deployment..."

    if ($Instalador.Extension -eq ".msi") {
        $procesoInst = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$($Instalador.FullName)`" /qn /norestart ALLUSERS=1" -Wait -PassThru
    } else {
        $procesoInst = Start-Process -FilePath$Instalador.FullName -ArgumentList "/S /silent /quiet /norestart" -Wait -PassThru
    }

    Write-Output "[+] Installer execution completed with ExitCode: $($procesoInst.ExitCode)"

    if ($procesoInst.ExitCode -ne 0) {
        exit $procesoInst.ExitCode
    }

} catch {
    Write-Error "[-] Deployment failure: $_"
    exit 1
} finally {
    # ---------------------------------------------------------------------
    # 6. SANITIZATION & TEARDOWN
    # ---------------------------------------------------------------------
    Write-Output "[+] Running cleanup routines..."
    Start-Process -FilePath "net.exe" -ArgumentList "use `"$ServerShare`" /delete /y" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null

    if (Test-Path $StagingPath) {
        Remove-Item -Path $StagingPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Output "[+] Deployment task cycle finished."
}
