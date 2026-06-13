# check-version.ps1 — Windows PowerShell 版本检查脚本
# 用法：powershell meta-harness/scripts/check-version.ps1
# 输出格式与 check-version.sh 一致，方便调用方解析

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

# 尝试获取远程 URL
Push-Location $MHRoot
try {
    $RemoteUrl = git remote get-url origin 2>$null
} finally {
    Pop-Location
}

if (-not $RemoteUrl) {
    Write-Host "CURRENT=$CurrentVersion"
    Write-Host "LATEST=unknown"
    Write-Host "UPDATE_AVAILABLE=false"
    exit 0
}

$LatestVersion = $null
$UpdateAvailable = $false

# 策略 1: 如果是 GitHub，尝试 raw VERSION 文件
if ($RemoteUrl -match "github.com") {
    $RawUrl = $RemoteUrl -replace 'https://github.com/', 'https://raw.githubusercontent.com/' `
                         -replace 'git@github.com:', 'https://raw.githubusercontent.com/' `
                         -replace '\.git$', ''
    $RawUrl = "$RawUrl/main/VERSION"
    
    try {
        $LatestVersion = (Invoke-WebRequest -Uri $RawUrl -TimeoutSec 5 -UseBasicParsing).Content.Trim()
    } catch {
        $LatestVersion = $null
    }
}

# 策略 2: 如果策略 1 失败，用 git ls-remote
if (-not $LatestVersion) {
    Push-Location $MHRoot
    try {
        $LocalHash = git rev-parse HEAD 2>$null
        $RemoteHash = (git ls-remote origin HEAD 2>$null | ForEach-Object { $_.Split()[0] })
        
        if ($RemoteHash -and $LocalHash -ne $RemoteHash) {
            $LatestVersion = "newer (commit differs)"
            $UpdateAvailable = $true
        } else {
            $LatestVersion = $CurrentVersion
        }
    } finally {
        Pop-Location
    }
} else {
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
    Write-Host ""
    Write-Host "  To update:"
    Write-Host "    powershell meta-harness/scripts/update-harness.ps1"
    Write-Host "=============================================="
}