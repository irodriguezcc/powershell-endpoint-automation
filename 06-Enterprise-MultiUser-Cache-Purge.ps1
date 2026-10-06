<#
.SYNOPSIS
    Deep system and multi-user browser cache cleanup routine for developer deployments and staging releases.
.DESCRIPTION
    Designed for automated execution via RMM (Action1 / Atera) across production and staging workstations:
    1. System Temp Cleanup: Clears Windows Temp, Prefetch, and SoftwareDistribution download caches.
    2. Multi-Profile Enumeration: Discovers all non-system user directories under SystemDrive\Users.
    3. Browser Cache Scrub: Recursively purges standard, Code Cache (V8), and GPUCache stores across:
       - Google Chrome (Default & additional profile containers)
       - Microsoft Edge (Default & additional profile containers)
       - Mozilla Firefox (cache2 and startupCache)
       - Brave Browser
    4. Per-User Temp Hygiene: Empties AppData\Local\Temp for each discovered profile.
    5. Network & System Reset: Empties Recycle Bin and flushes local DNS client resolver cache.
.NOTES
    Author: Iván Felipe Rodríguez C.
    Version: 1.0
#>

#Requires -RunAsAdministrator

Write-Output "[+] Initiating deep system and multi-user environment cache maintenance..."

# =====================================================================
# 1. WINDOWS SYSTEM TEMPORARY STORAGE PURGE
# =====================================================================
Write-Output "[+] Purging system-level caches (Temp, Prefetch, SoftwareDistribution)..."

$SystemCachePaths = @(
    "${env:SystemRoot}\Temp\*",
    "${env:SystemRoot}\Prefetch\*",
    "${env:SystemRoot}\SoftwareDistribution\Download\*"
)

foreach ($path in $SystemCachePaths) {
    if (Test-Path -Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

# =====================================================================
# 2. MULTI-USER PROFILE BROWSER & LOCAL TEMP CLEANUP
# =====================================================================
Write-Output "[+] Scanning user profiles for application and browser caches..."

$UsersBasePath = "${env:SystemDrive}\Users"
$UserProfiles = Get-ChildItem -Path $UsersBasePath -Directory -ErrorAction SilentlyContinue | Where-Object { 
    $_.Name -notmatch "^(Public|Default|Default User|All Users)$" 
}

foreach ($profile in $UserProfiles) {
    $userRoot = $profile.FullName
    Write-Output " -> Processing user profile: $($profile.Name)"

    # A. User Local Temp directory
    $UserTemp = Join-Path -Path $userRoot -ChildPath "AppData\Local\Temp\*"
    if (Test-Path -Path $UserTemp) {
        Remove-Item -Path $UserTemp -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }

    # B. Google Chrome Caches
    $ChromePaths = @(
        "$userRoot\AppData\Local\Google\Chrome\User Data\Default\Cache\*",
        "$userRoot\AppData\Local\Google\Chrome\User Data\Default\Code Cache\*",
        "$userRoot\AppData\Local\Google\Chrome\User Data\Default\GPUCache\*",
        "$userRoot\AppData\Local\Google\Chrome\User Data\Profile *\Cache\*",
        "$userRoot\AppData\Local\Google\Chrome\User Data\Profile *\Code Cache\*",
        "$userRoot\AppData\Local\Google\Chrome\User Data\Profile *\GPUCache\*"
    )
    foreach ($target in $ChromePaths) {
        if (Test-Path -Path $target) { 
            Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue | Out-Null 
        }
    }

    # C. Microsoft Edge Caches
    $EdgePaths = @(
        "$userRoot\AppData\Local\Microsoft\Edge\User Data\Default\Cache\*",
        "$userRoot\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache\*",
        "$userRoot\AppData\Local\Microsoft\Edge\User Data\Default\GPUCache\*",
        "$userRoot\AppData\Local\Microsoft\Edge\User Data\Profile *\Cache\*",
        "$userRoot\AppData\Local\Microsoft\Edge\User Data\Profile *\Code Cache\*",
        "$userRoot\AppData\Local\Microsoft\Edge\User Data\Profile *\GPUCache\*"
    )
    foreach ($target in $EdgePaths) {
        if (Test-Path -Path $target) { 
            Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue | Out-Null 
        }
    }

    # D. Mozilla Firefox Caches
    $FirefoxPaths = @(
        "$userRoot\AppData\Local\Mozilla\Firefox\Profiles\*\cache2\*",
        "$userRoot\AppData\Local\Mozilla\Firefox\Profiles\*\startupCache\*"
    )
    foreach ($target in $FirefoxPaths) {
        if (Test-Path -Path $target) { 
            Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue | Out-Null 
        }
    }

    # E. Brave Browser Caches
    $BravePaths = @(
        "$userRoot\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\Cache\*",
        "$userRoot\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\Code Cache\*",
        "$userRoot\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\GPUCache\*"
    )
    foreach ($target in $BravePaths) {
        if (Test-Path -Path $target) { 
            Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue | Out-Null 
        }
    }
}

# =====================================================================
# 3. RECYCLE BIN AND RESOLVER RECOVERY
# =====================================================================
Write-Output "[+] Emptying workstation Recycle Bin across all volumes..."
Clear-RecycleBin -Force -ErrorAction SilentlyContinue | Out-Null

Write-Output "[+] Flushing DNS Client Resolver Cache..."
Clear-DnsClientCache -ErrorAction SilentlyContinue | Out-Null

Write-Output "[+] Deep cache remediation finished successfully. Workstation state refreshed."
exit 0
