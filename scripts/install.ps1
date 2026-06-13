# install.ps1 — Windows PowerShell 安装 meta-harness
# 用法：powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/eeyzs1/meta_harness/main/scripts/install.ps1 | iex"
#      或：在已有 submodule 的项目中：powershell meta-harness/scripts/install.ps1

param()
$ErrorActionPreference = "Stop"

Write-Host "=== Meta-Harness Install ===" -ForegroundColor Cyan
Write-Host ""

# === 检测 ===

# 是否已经在 submodule 中？
if ((Test-Path "meta-harness/VERSION") -and (Test-Path ".gitmodules")) {
    Write-Host "Detected: submodule already present" -ForegroundColor Green
    Write-Host "Running init..."
    & "meta-harness/scripts/init-harness-submodule.ps1"
    exit 0
}

# 是否在 meta-harness 仓库自身中？
if (Test-Path "AGENTS.md") {
    $Content = Get-Content "AGENTS.md" -Raw
    if ($Content -match "META-HARNESS: you GENERATE") {
        Write-Host "This is the meta-harness repository itself." -ForegroundColor Yellow
        Write-Host "install.ps1 is for APPLICATION projects that want to USE meta-harness."
        Write-Host "To install in another project, use the iwr command:"
        Write-Host ""
        Write-Host "  powershell -ExecutionPolicy Bypass -Command `"iwr <url>/install.ps1 | iex`""
        exit 1
    }
}

# 检查 git
try {
    git rev-parse --git-dir 2>$null | Out-Null
} catch {
    Write-Host "ERROR: Not in a git repository." -ForegroundColor Red
    Write-Host "Initialize git first:"
    Write-Host "  git init"
    Write-Host "  git remote add origin <your-repo-url>"
    exit 1
}

# 检查是否已有 meta-harness 目录
if (Test-Path "meta-harness") {
    Write-Host "meta-harness/ directory already exists." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If this is an old copy-paste install, use migrate instead:"
    Write-Host "  powershell -ExecutionPolicy Bypass -Command `"iwr <url>/bootstrap-update.ps1 | iex`""
    Write-Host ""
    $Confirm = Read-Host "Overwrite with submodule? [y/N]"
    if ($Confirm -ne "y" -and $Confirm -ne "Y") { Write-Host "Aborted."; exit 0 }
    Remove-Item -Recurse -Force meta-harness
}

# === 安装 ===

Write-Host "Adding meta-harness as submodule..." -ForegroundColor Green
git submodule add git@github.com:eeyzs1/meta_harness.git meta-harness
Write-Host ""

Write-Host "Initializing project structure..." -ForegroundColor Green
& "meta-harness/scripts/init-harness-submodule.ps1"
Write-Host ""

Write-Host "=== Install Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Edit .meta-harness/project.yaml — set your project name and settings"
Write-Host "  2. Commit: git add meta-harness .meta-harness AGENTS.md .gitmodules"
Write-Host '     git commit -m "Add meta-harness framework"'
Write-Host ""
Write-Host "Framework update:"
Write-Host "  powershell meta-harness/scripts/update-harness.ps1"