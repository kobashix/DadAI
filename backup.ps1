# backup.ps1
# Backs up the entire Andrew Pennington Digital Twin project to a drive or folder.
# Run this any time you make changes to keep the backup current.
#
# Usage:
#   .\backup.ps1                        # prompts for destination
#   .\backup.ps1 -Dest "E:\"           # backup to E: drive
#   .\backup.ps1 -Dest "D:\Backup"     # backup to a specific folder

param(
    [string]$Dest = ""
)

# ── pick destination ────────────────────────────────────────────────────────
if (-not $Dest) {
    $Dest = Read-Host "Enter backup destination (e.g. E:\ or D:\Backup)"
}
$Dest = $Dest.TrimEnd("\")

$ProjectDest = "$Dest\Andrew-Twin"
$ModelDest   = "$ProjectDest\ollama-models"

Write-Host ""
Write-Host "Backing up to: $ProjectDest" -ForegroundColor Cyan
Write-Host ""

# ── create folders ──────────────────────────────────────────────────────────
$null = New-Item -ItemType Directory -Force -Path $ProjectDest
$null = New-Item -ItemType Directory -Force -Path "$ModelDest\blobs"
$null = New-Item -ItemType Directory -Force -Path "$ModelDest\manifests"

# ── copy project source files ───────────────────────────────────────────────
Write-Host "Copying project files..." -ForegroundColor Yellow
$SourceDir = $PSScriptRoot
$FilesToCopy = @(
    "Legacy.Modelfile",
    "StrongTwin.Modelfile",
    "Twin.Modelfile",
    "Interviewer.Modelfile",
    "MyIdentity.txt",
    "twin_chat.py",
    "CLAUDE.md",
    "backup.ps1",
    "setup.bat",
    "start.bat",
    "FOR_MY_DAUGHTERS.txt"
)
foreach ($f in $FilesToCopy) {
    $src = Join-Path $SourceDir $f
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $ProjectDest -Force
        Write-Host "  + $f" -ForegroundColor Green
    } else {
        Write-Host "  - $f (not found, skipping)" -ForegroundColor DarkGray
    }
}

# copy ai team folder if it exists
$aiTeam = Join-Path $SourceDir "ai team"
if (Test-Path $aiTeam) {
    Copy-Item -Path $aiTeam -Destination $ProjectDest -Recurse -Force
    Write-Host "  + ai team\" -ForegroundColor Green
}

# ── copy Ollama models ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "Collecting Ollama model files..." -ForegroundColor Yellow

$OllamaBase  = "$env:USERPROFILE\.ollama\models"
$BlobsDir    = "$OllamaBase\blobs"
$ManifestBase = "$OllamaBase\manifests\registry.ollama.ai\library"

# models we care about
$TwinModels = @("my-twin", "andrew-legacy", "personal-interviewer")

# collect blob digests needed by these models
$NeedBlobs = @{}

foreach ($model in $TwinModels) {
    $manifestPath = "$ManifestBase\$model\latest"
    if (-not (Test-Path $manifestPath)) {
        Write-Host "  - $model : not built yet, skipping" -ForegroundColor DarkGray
        continue
    }

    Write-Host "  Processing $model..." -ForegroundColor Cyan

    # copy manifest (preserve folder structure)
    $destManifestDir = "$ModelDest\manifests\registry.ollama.ai\library\$model"
    $null = New-Item -ItemType Directory -Force -Path $destManifestDir
    Copy-Item -Path $manifestPath -Destination "$destManifestDir\latest" -Force

    # parse manifest for blob digests
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    $layers = @($manifest.config) + @($manifest.layers)
    foreach ($layer in $layers) {
        if ($layer.digest) {
            $blobFile = $layer.digest -replace "sha256:", "sha256-"
            $NeedBlobs[$blobFile] = $true
        }
    }
}

# copy required blobs
Write-Host ""
Write-Host "Copying model blobs (this may take a few minutes for large files)..." -ForegroundColor Yellow
$CopiedSize = 0
foreach ($blobName in $NeedBlobs.Keys) {
    $src = "$BlobsDir\$blobName"
    $dst = "$ModelDest\blobs\$blobName"
    if (-not (Test-Path $src)) {
        Write-Host "  - $blobName not found in ollama blobs dir" -ForegroundColor Red
        continue
    }
    if (Test-Path $dst) {
        # skip if already there and same size
        $srcSize = (Get-Item $src).Length
        $dstSize = (Get-Item $dst).Length
        if ($srcSize -eq $dstSize) {
            Write-Host "  = $blobName (already up to date)" -ForegroundColor DarkGray
            continue
        }
    }
    $sizeMB = [math]::Round((Get-Item $src).Length / 1MB, 0)
    Write-Host "  + $blobName  ($sizeMB MB)" -ForegroundColor Green
    Copy-Item -Path $src -Destination $dst -Force
    $CopiedSize += (Get-Item $src).Length
}

# ── write manifest of backup ─────────────────────────────────────────────────
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$summary = @"
Andrew Pennington Digital Twin — Backup
Created: $timestamp
Machine: $env:COMPUTERNAME

Models included:
$(($TwinModels | ForEach-Object { "  - $_" }) -join "`n")

To restore on a new Windows PC:
  1. Install Python  : https://www.python.org/downloads/
  2. Install Ollama  : https://ollama.com/download/windows
  3. Double-click setup.bat
  4. Double-click start.bat

Questions? Read FOR_MY_DAUGHTERS.txt first.
"@
$summary | Out-File -FilePath "$ProjectDest\BACKUP_INFO.txt" -Encoding utf8

Write-Host ""
Write-Host "────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host " Backup complete: $ProjectDest" -ForegroundColor Green
$totalGB = [math]::Round((Get-ChildItem $ProjectDest -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
Write-Host " Total size: $totalGB GB" -ForegroundColor Green
Write-Host "────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
