# build_installer.ps1  —  run with: .\build_installer.ps1
Set-Location $PSScriptRoot
$ErrorActionPreference = "Stop"

function Step($n, $msg) { Write-Host "`n  [$n] $msg" -ForegroundColor Cyan }
function OK($msg)        { Write-Host "      $msg" -ForegroundColor Green }
function Fail($msg)      { Write-Host "`n  ERROR: $msg" -ForegroundColor Red; Read-Host "Press Enter to exit"; exit 1 }

Write-Host "`n  ================================================" -ForegroundColor White
Write-Host '   Building "Install Dad''s App.exe"'              -ForegroundColor White
Write-Host "  ================================================`n" -ForegroundColor White

# ── 1. Build Talk to Dad.exe ─────────────────────────────────────────────────
Step 1 "Building Talk to Dad.exe..."
if (Test-Path "dist\Talk to Dad.exe") {
    OK "Already built, skipping."
} else {
    pyinstaller --onefile --noconsole --name "Talk to Dad" --hidden-import requests talk_to_dad.py
    if ($LASTEXITCODE -ne 0) { Fail "PyInstaller failed." }
    OK "Built."
}

# ── 2. Download Ollama installer ─────────────────────────────────────────────
Step 2 "Downloading Ollama installer..."
if (Test-Path "OllamaSetup.exe") {
    OK "Already present, skipping."
} else {
    $ollamaUrl = "https://github.com/ollama/ollama/releases/latest/download/OllamaSetup.exe"
    Invoke-WebRequest -Uri $ollamaUrl -OutFile "OllamaSetup.exe" -UseBasicParsing
    OK "Downloaded."
}

# ── 3. Find or install Inno Setup ────────────────────────────────────────────
Step 3 "Locating Inno Setup..."

function Find-ISCC {
    # common install paths
    $paths = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    )
    foreach ($p in $paths) { if (Test-Path $p) { return $p } }

    # registry lookup
    $regKeys = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1"
    )
    foreach ($k in $regKeys) {
        if (Test-Path $k) {
            $loc = (Get-ItemProperty $k -ErrorAction SilentlyContinue).InstallLocation
            if ($loc -and (Test-Path "$loc\ISCC.exe")) { return "$loc\ISCC.exe" }
        }
    }
    return $null
}

$iscc = Find-ISCC

if (-not $iscc) {
    Write-Host "      Not found. Installing via winget..." -ForegroundColor Yellow
    winget install -e --id JRSoftware.InnoSetup --silent --accept-package-agreements --accept-source-agreements
    # refresh PATH so new installs are visible
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
    $iscc = Find-ISCC
}

if (-not $iscc) { Fail "Could not find ISCC.exe. Install Inno Setup from https://jrsoftware.org/isdl.php then run again." }
OK "Found: $iscc"

# ── 4. Compile the installer ─────────────────────────────────────────────────
Step 4 "Compiling installer..."
& $iscc "installer.iss"
if ($LASTEXITCODE -ne 0) { Fail "Inno Setup compile failed." }

Write-Host "`n  ================================================" -ForegroundColor Green
Write-Host "   Done! Installer ready:" -ForegroundColor Green
Write-Host "     Output\Install Dad's App.exe" -ForegroundColor White
Write-Host "`n   Copy this file + the ollama-models\ folder" -ForegroundColor White
Write-Host "   to each daughter's drive." -ForegroundColor White
Write-Host "  ================================================`n" -ForegroundColor Green
Read-Host "Press Enter to exit"
