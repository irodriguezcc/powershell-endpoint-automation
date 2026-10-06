<#
.SYNOPSIS
    Automated remediation and silent repair routine for Microsoft 365 / Office Click-to-Run.
.DESCRIPTION
    Terminates orphaned Office processes, purges stale lockfiles, and initiates 
    a silent background Quick Repair routine. Designed for unattended RMM execution.
.NOTES
    Author: Iván Felipe Rodríguez C.
    Version: 1.2
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [ValidateSet("Quick", "Full")]
    [string]$RepairType = "Quick",
    [string]$LogPath = "$env:ProgramData\ITOps\Logs\Office-Remediation.log"
)

# Initialize logging directory
$logDir = Split-Path -Path $LogPath -Parent
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param ([string]$Message, [ValidateSet("INFO", "WARN", "ERROR")] $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Output $logEntry
    Add-Content -Path $LogPath -Value $logEntry
}

Write-Log "Starting Microsoft 365 Click-to-Run remediation process..."

# 1. Gracefully terminate lingering Office processes
$officeProcesses = @("WINWORD", "EXCEL", "POWERPNT", "OUTLOOK", "ONENOTE", "MSACCESS", "teams")

foreach ($proc in $officeProcesses) {
    $running = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($running) {
        Write-Log "Terminating lingering process: $proc (PID: $($running.Id -join ','))" -Level WARN
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
    }
}

# 2. Locate Click-to-Run executable
$c2rPath = "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeClickToRun.exe"

if (-not (Test-Path -Path $c2rPath)) {
    Write-Log "OfficeClickToRun.exe not found at standard path: $c2rPath" -Level ERROR
    exit 1
}

# 3. Execute silent repair
try {
    Write-Log "Initiating silent Office $RepairType repair routine..."
    
    $repairArg = if ($RepairType -eq "Full") { "repairtype=full" } else { "repairtype=quick" }
    $processArgs = "scenario=Repair platform=x64 $repairArg forceappshutdown=True displaylevel=False"

    $process = Start-Process -FilePath $c2rPath -ArgumentList $processArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Log "Office Click-to-Run repair completed successfully (ExitCode 0)."
        exit 0
    } else {
        Write-Log "Repair process completed with non-zero exit code: $($process.ExitCode)" -Level WARN
        exit $process.ExitCode
    }
}
catch {
    Write-Log "Unexpected exception during remediation: $($_.Exception.Message)" -Level ERROR
    exit 2
}
