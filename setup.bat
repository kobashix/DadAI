@echo off
title Setting Up Dad's Digital Twin
color 0A

echo.
echo  ============================================================
echo   Andrew Pennington - Digital Twin  ^|  First-Time Setup
echo  ============================================================
echo.
echo  This will set up the app on your computer.
echo  You only need to do this once.
echo.
pause

:: ── Check Python ──────────────────────────────────────────────────────────
echo.
echo  [1/4] Checking for Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo  Python is not installed.
    echo.
    echo  Please download and install Python from:
    echo    https://www.python.org/downloads/
    echo.
    echo  IMPORTANT: On the first installer screen, check the box
    echo  that says "Add Python to PATH" before clicking Install.
    echo.
    echo  After installing Python, run this setup again.
    echo.
    start https://www.python.org/downloads/
    pause
    exit /b 1
)
echo  Python found.

:: ── Check Ollama ──────────────────────────────────────────────────────────
echo.
echo  [2/4] Checking for Ollama...
ollama --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo  Ollama is not installed.
    echo.
    echo  Please download and install Ollama from:
    echo    https://ollama.com/download/windows
    echo.
    echo  After installing Ollama, run this setup again.
    echo.
    start https://ollama.com/download/windows
    pause
    exit /b 1
)
echo  Ollama found.

:: ── Install Python requests library ───────────────────────────────────────
echo.
echo  [3/4] Installing required Python packages...
pip install requests --quiet
echo  Done.

:: ── Import Ollama models ───────────────────────────────────────────────────
echo.
echo  [4/4] Loading Dad's models into Ollama...
echo  (This copies the model files - may take a minute)
echo.

set OLLAMA_MODELS=%USERPROFILE%\.ollama\models
set BACKUP_MODELS=%~dp0ollama-models

:: Copy blobs
if exist "%BACKUP_MODELS%\blobs" (
    echo  Copying model data...
    xcopy /s /y /q "%BACKUP_MODELS%\blobs\*" "%OLLAMA_MODELS%\blobs\" >nul
    echo  Model data copied.
) else (
    echo  WARNING: No model data found in this backup folder.
)

:: Copy manifests
if exist "%BACKUP_MODELS%\manifests" (
    xcopy /s /y /q "%BACKUP_MODELS%\manifests\*" "%OLLAMA_MODELS%\manifests\" >nul
    echo  Model names registered.
)

:: ── Create desktop shortcut ────────────────────────────────────────────────
echo.
echo  Creating desktop shortcut...
set SCRIPT_DIR=%~dp0
set SHORTCUT=%USERPROFILE%\Desktop\Talk to Dad.lnk
powershell -NoProfile -Command ^
  "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%SHORTCUT%'); $s.TargetPath = 'python'; $s.Arguments = '\"%SCRIPT_DIR%twin_chat.py\"'; $s.WorkingDirectory = '%SCRIPT_DIR%'; $s.IconLocation = 'shell32.dll,13'; $s.Description = 'Talk to Dad'; $s.Save()"
echo  Shortcut created on your Desktop: "Talk to Dad"

echo.
echo  ============================================================
echo   Setup complete!
echo.
echo   Double-click "Talk to Dad" on your Desktop to start.
echo  ============================================================
echo.
pause
