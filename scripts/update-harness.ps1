# update-harness.ps1 — Windows PowerShell 一键更新脚本
# 用法：powershell meta-harness/scripts/update-harness.ps1
# 做三件事：git pull → migrate project.yaml → git commit

param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MHRoot = Split-Path -Parent $ScriptDir
$ProjectRoot = Split-Path -Parent $MHRoot

Write-Host "=== Meta-Harness Update ==="
Write-Host ""

# Step 1: 检查是否 submodule
$Gitmodules = Join-Path $ProjectRoot ".gitmodules"
if (-not (Test-Path $Gitmodules)) {
    Write-Error "No .gitmodules found. Is meta-harness installed as a submodule?"
    Write-Host "Run: git submodule add <url> meta-harness"
    exit 1
}

$Content = Get-Content $Gitmodules -Raw
if ($Content -notmatch "meta-harness") {
    Write-Error "meta-harness not found in .gitmodules."
    exit 1
}

# Step 2: 记录当前版本
$VersionFile = Join-Path $MHRoot "VERSION"
$CurrentVersion = if (Test-Path $VersionFile) { (Get-Content $VersionFile).Trim() } else { "unknown" }
Write-Host "Current version: $CurrentVersion"

# Step 3: Git pull
Write-Host ""
Write-Host "--- Pulling latest framework ---"
Push-Location $MHRoot
try {
    git pull origin main
} finally {
    Pop-Location
}

$NewVersion = if (Test-Path $VersionFile) { (Get-Content $VersionFile).Trim() } else { "unknown" }
Write-Host "Updated to: $NewVersion"

# Step 4: 迁移 project.yaml
$MigrateScript = Join-Path $MHRoot "scripts/migrate.ps1"
if (Test-Path $MigrateScript) {
    Write-Host ""
    Write-Host "--- Migrating project configuration ---"
    $ProjectYaml = Join-Path $ProjectRoot ".meta-harness/project.yaml"
    if (Test-Path $ProjectYaml) {
        & $MigrateScript -ProjectYamlPath $ProjectYaml
    } else {
        Write-Host "  (no project.yaml found, skipping)"
    }
}

# Step 5: 提交更新
Write-Host ""
Write-Host "--- Committing update ---"
Push-Location $ProjectRoot
try {
    git add meta-harness
    $ProjectYaml = Join-Path $ProjectRoot ".meta-harness/project.yaml"
    if (Test-Path $ProjectYaml) {
        git add $ProjectYaml
    }

    $Diff = git diff --cached --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "No changes to commit (already up to date)."
    } else {
        git commit -m "chore: update meta-harness $CurrentVersion -> $NewVersion"
        Write-Host ""
        Write-Host "=== Committed: meta-harness $CurrentVersion -> $NewVersion ==="
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Done. Framework is now at $NewVersion."