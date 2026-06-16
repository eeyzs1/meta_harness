# check-version.ps1 — Windows PowerShell 版本检查脚本
# 用法：powershell meta-harness/scripts/check-version.ps1
# 输出格式与 check-version.sh 一致，方便调用方解析
# 协议：自动支持 SSH 和 HTTPS remote（raw URL 转换天然兼容两种来源），
#       如果当前 remote 不可达，会临时切换到另一种协议重试。
#       不会持久改写 remote URL（脚本结束前会恢复原值）。

param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MHRoot = Split-Path -Parent $ScriptDir

$MH_REPO_SSH = "git@github.com:eeyzs1/meta_harness.git"
$MH_REPO_HTTPS = "https://github.com/eeyzs1/meta_harness.git"

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
    Write-Host "WARNING: Cannot determine remote URL. Skipping version check."
    Write-Host "CURRENT=$CurrentVersion"
    Write-Host "LATEST=unknown"
    Write-Host "UPDATE_AVAILABLE=false"
    exit 0
}

# 协议探测
$Proto = "https"
$AltRemote = $MH_REPO_SSH
if ($RemoteUrl -match "^git@github.com:") {
    $Proto = "ssh"
    $AltRemote = $MH_REPO_HTTPS
}

$LatestVersion = $null
$UpdateAvailable = $false

# 策略 1: GitHub raw VERSION 文件（SSH/HTTPS remote 转换结果一致）
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

# 策略 2: git ls-remote 兜底（带协议回退）
if (-not $LatestVersion) {
    Push-Location $MHRoot
    try {
        $LocalHash = git rev-parse HEAD 2>$null
    } finally {
        Pop-Location
    }

    $RemoteHash = $null

    # 第一次：当前 remote
    Push-Location $MHRoot
    try {
        $lsOutput = git ls-remote origin HEAD 2>$null
        if ($lsOutput) {
            $RemoteHash = ($lsOutput -split "`n" | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1)
        }
    } finally {
        Pop-Location
    }

    # 失败则切到备用协议
    if (-not $RemoteHash -and $LocalHash) {
        $OtherProto = if ($Proto -eq "ssh") { "https" } else { "ssh" }
        Write-Host "  WARNING: $Proto remote $RemoteUrl unreachable, retrying with $OtherProto..." -ForegroundColor Yellow
        $SavedRemote = $RemoteUrl

        Push-Location $MHRoot
        try {
            git remote set-url origin $AltRemote 2>$null | Out-Null
            $lsOutput = git ls-remote origin HEAD 2>$null
            if ($lsOutput) {
                $RemoteHash = ($lsOutput -split "`n" | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1)
            }
        } finally {
            # 还原 remote
            git remote set-url origin $SavedRemote 2>$null | Out-Null
            Pop-Location
        }
    }

    if ($RemoteHash -and $LocalHash -ne $RemoteHash) {
        $LatestVersion = "newer (commit differs)"
        $UpdateAvailable = $true
    } else {
        $LatestVersion = $CurrentVersion
        $UpdateAvailable = $false
    }
} else {
    if ($CurrentVersion -ne $LatestVersion) {
        $UpdateAvailable = $true
    } else {
        $UpdateAvailable = $false
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
