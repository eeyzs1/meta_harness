# check-version.ps1 — Windows PowerShell 版本检查脚本
# 用法：powershell -ExecutionPolicy Bypass -File scripts/check-version.ps1

param()

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MHRoot = Split-Path -Parent $ScriptDir
$VersionFile = Join-Path $MHRoot "VERSION"

if (-not (Test-Path $VersionFile)) {
    Write-Error "VERSION file not found at $VersionFile"
    exit 1
}

$CurrentVersion = (Get-Content $VersionFile).Trim()

# Get remote URL
$prevLoc = Get-Location
Set-Location $MHRoot
$RemoteUrl = git remote get-url origin 2>$null
Set-Location $prevLoc

if (-not $RemoteUrl) {
    Write-Host "CURRENT=$CurrentVersion"
    Write-Host "LATEST=unknown"
    Write-Host "UPDATE_AVAILABLE=false"
    exit 0
}

# Determine protocol
$Proto = "https"
$AltRemote = "git@github.com:eeyzs1/meta_harness.git"
if ($RemoteUrl -match "^git@github.com:") {
    $Proto = "ssh"
    $AltRemote = "https://github.com/eeyzs1/meta_harness.git"
}

# Strategy 1: Try GitHub raw URL
$LatestVersion = $null
if ($RemoteUrl -match "github.com") {
    $RawUrl = $RemoteUrl
    $RawUrl = $RawUrl -replace 'https://github.com/', 'https://raw.githubusercontent.com/'
    $RawUrl = $RawUrl -replace 'git@github.com:', 'https://raw.githubusercontent.com/'
    $RawUrl = $RawUrl -replace '\.git$', ''
    $RawUrl = "$RawUrl/main/VERSION"

    try {
        $LatestVersion = (Invoke-WebRequest -Uri $RawUrl -TimeoutSec 5 -UseBasicParsing).Content.Trim()
    } catch {
        $LatestVersion = $null
    }
}

# Strategy 2: git ls-remote fallback
if (-not $LatestVersion) {
    $prevLoc = Get-Location
    Set-Location $MHRoot
    $LocalHash = git rev-parse HEAD 2>$null
    Set-Location $prevLoc

    $prevLoc = Get-Location
    Set-Location $MHRoot
    $lsOutput = git ls-remote origin HEAD 2>$null
    Set-Location $prevLoc

    $RemoteHash = $null
    if ($lsOutput) {
        $parts = $lsOutput -split '\s+'
        $RemoteHash = $parts[0]
    }

    # If current remote failed, try alternate protocol directly (no remote mutation)
    if ((-not $RemoteHash) -and $LocalHash) {
        $OtherProto = "https"
        if ($Proto -eq "ssh") { $OtherProto = "ssh" }
        Write-Host "WARNING: Retrying with $OtherProto protocol..."

        $prevLoc = Get-Location
        Set-Location $MHRoot
        # Use the alternate URL directly in ls-remote to avoid mutating git config
        $lsOutput = git ls-remote $AltRemote HEAD 2>$null
        Set-Location $prevLoc

        if ($lsOutput) {
            $parts = $lsOutput -split '\s+'
            $RemoteHash = $parts[0]
        }
    }

    $UpdateAvailable = $false
    if ($RemoteHash) {
        if ($LocalHash -ne $RemoteHash) {
            $LatestVersion = "newer (commit differs)"
            $UpdateAvailable = $true
        } else {
            $LatestVersion = $CurrentVersion
        }
    } else {
        $LatestVersion = $CurrentVersion
    }
} else {
    $UpdateAvailable = $false
    if ($CurrentVersion -ne $LatestVersion) {
        $UpdateAvailable = $true
    }
}

Write-Host "CURRENT=$CurrentVersion"
Write-Host "LATEST=$LatestVersion"
Write-Host "UPDATE_AVAILABLE=$UpdateAvailable"

if ($UpdateAvailable) {
    Write-Host ""
    Write-Host "=============================================="
    Write-Host "  Meta-Harness update available!"
    Write-Host "  Current: $CurrentVersion"
    Write-Host "  Latest:  $LatestVersion"
    Write-Host "  To update: powershell scripts/update-harness.ps1"
    Write-Host "=============================================="
}