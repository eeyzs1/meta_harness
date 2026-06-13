# bootstrap-update.ps1 — Windows PowerShell 泛化入口
# 在任何项目中更新/安装 meta-harness
#
# 用法：
#   powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/eeyzs1/meta_harness/main/scripts/bootstrap-update.ps1 | iex"
# 或本地：
#   powershell meta-harness/scripts/bootstrap-update.ps1

param()

$ErrorActionPreference = "Stop"

function Write-Banner { Write-Host "=== Meta-Harness Bootstrap ===" -ForegroundColor Cyan; Write-Host "" }

function Out-Green { Write-Host $args[0] -ForegroundColor Green }
function Out-Yellow { Write-Host $args[0] -ForegroundColor Yellow }
function Out-Red { Write-Host $args[0] -ForegroundColor Red }

Write-Banner

# === 检测状态 ===
$Type = "D"
$HasGitmodules = Test-Path ".gitmodules"

if ($HasGitmodules) {
    $Content = Get-Content ".gitmodules" -Raw
    if ($Content -match "meta-harness") {
        if (Test-Path "meta-harness/VERSION") {
            $Type = "A"
        }
    }
}

if ($Type -eq "D") {
    if ((Test-Path "meta/interpreter.md") -and (Test-Path "seeds/guard.py")) {
        $Type = "B"
    }
}

if ($Type -eq "D") {
    if ((Test-Path ".meta-harness/meta/interpreter.md") -or (Test-Path ".meta-harness/seeds/guard.py")) {
        $Type = "C"
    }
}

switch ($Type) {
    "A" {
        Out-Green "Detected: submodule installation"
        Write-Host ""
        if (Test-Path "meta-harness/scripts/update-harness.ps1") {
            Write-Host "Updating framework..."
            & "meta-harness/scripts/update-harness.ps1"
        } else {
            Out-Red "ERROR: update-harness.ps1 not found in submodule."
            Write-Host "Try: cd meta-harness; git pull origin main"
            exit 1
        }
    }
    
    "B" {
        Out-Yellow "Detected: old copy-paste (framework files at root)"
        Write-Host "This project was installed the old way — framework files are scattered in the project root."
        Write-Host ""
        Write-Host "Migration needed. This will:"
        Write-Host "  - Back up your project config and memory"
        Write-Host "  - Remove old framework files"
        Write-Host "  - Add meta-harness as a git submodule"
        Write-Host "  - Restore your local files"
        Write-Host ""
        $Confirm = Read-Host "Start migration? [y/N]"
        if ($Confirm -ne "y" -and $Confirm -ne "Y") { Write-Host "Aborted."; exit 0 }
        Write-Host ""
        
        $TempScript = Join-Path $env:TEMP "mh-migrate-legacy.ps1"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/eeyzs1/meta_harness/main/scripts/migrate-legacy.ps1" -OutFile $TempScript
        & $TempScript
        Remove-Item $TempScript -Force
    }
    
    "C" {
        Out-Yellow "Detected: old copy-paste (framework files in .meta-harness/)"
        Write-Host "This project was installed the old way — framework files are inside .meta-harness/."
        Write-Host ""
        $Confirm = Read-Host "Start migration? [y/N]"
        if ($Confirm -ne "y" -and $Confirm -ne "Y") { Write-Host "Aborted."; exit 0 }
        Write-Host ""
        
        $TempScript = Join-Path $env:TEMP "mh-migrate-legacy.ps1"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/eeyzs1/meta_harness/main/scripts/migrate-legacy.ps1" -OutFile $TempScript
        & $TempScript
        Remove-Item $TempScript -Force
    }
    
    "D" {
        Out-Yellow "Detected: no meta-harness installation"
        Write-Host ""
        Write-Host "To install meta-harness in this project:"
        Write-Host ""
        Write-Host "  1. Add as submodule:"
        Write-Host "     git submodule add git@github.com:eeyzs1/meta_harness.git meta-harness"
        Write-Host ""
        Write-Host "  2. Run init script:"
        Write-Host "     powershell meta-harness/scripts/init-harness-submodule.ps1"
        Write-Host ""
        Write-Host "Or use the one-liner:"
        Write-Host "  powershell -ExecutionPolicy Bypass -Command `"iwr <url>/install.ps1 | iex`""
        Write-Host ""
        $Confirm = Read-Host "Install now? [y/N]"
        if ($Confirm -ne "y" -and $Confirm -ne "Y") { Write-Host "Aborted."; exit 0 }
        Write-Host ""
        
        Write-Host "Adding submodule..."
        git submodule add git@github.com:eeyzs1/meta_harness.git meta-harness
        Write-Host ""
        
        Write-Host "Initializing..."
        & "meta-harness/scripts/init-harness-submodule.ps1"
    }
}

Write-Host ""
Out-Green "=== Done ==="
Write-Host ""
Write-Host "Next time an AI agent works on this project, it will auto-check for updates."