@echo off
title Building Installer...
cd /d "%~dp0"

echo.
echo  ================================================
echo   Building "Install Dad's App.exe"
echo  ================================================
echo.

:: ── Step 1: Build the EXE (if not already done) ───────────────────────────
if not exist "dist\Talk to Dad.exe" (
    echo  Building Talk to Dad.exe...
    pyinstaller --onefile --noconsole --name "Talk to Dad" --hidden-import requests talk_to_dad.py
    if errorlevel 1 ( echo  PyInstaller failed. & pause & exit /b 1 )
    echo  EXE built.
) else (
    echo  Talk to Dad.exe already built, skipping.
)

:: ── Step 2: Download Ollama installer if not present ──────────────────────
if not exist "OllamaSetup.exe" (
    echo  Downloading Ollama installer...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://ollama.com/download/windows' -OutFile 'OllamaSetup.exe'"
    if errorlevel 1 ( echo  Download failed. Check your internet connection. & pause & exit /b 1 )
    echo  Ollama installer downloaded.
) else (
    echo  OllamaSetup.exe already present, skipping download.
)

:: ── Step 3: Find and run Inno Setup compiler ──────────────────────────────
set ISCC=
for %%p in (
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    "C:\Program Files\Inno Setup 6\ISCC.exe"
    "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
) do (
    if exist %%p set ISCC=%%p
)

if "%ISCC%"=="" (
    echo.
    echo  Inno Setup not found. Downloading and installing...
    powershell -NoProfile -Command "winget install -e --id JRSoftware.InnoSetup --silent --accept-package-agreements --accept-source-agreements"
    :: Try again after install
    for %%p in (
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    ) do (
        if exist %%p set ISCC=%%p
    )
)

if "%ISCC%"=="" (
    echo.
    echo  Could not find ISCC.exe. Please install Inno Setup from:
    echo    https://jrsoftware.org/isdl.php
    echo  Then run this script again.
    pause
    exit /b 1
)

echo  Using Inno Setup: %ISCC%
echo  Compiling installer...
%ISCC% installer.iss
if errorlevel 1 ( echo  Inno Setup compile failed. & pause & exit /b 1 )

echo.
echo  ================================================
echo   Done! Installer is in the Output folder:
echo     Output\Install Dad's App.exe
echo.
echo   Copy this + the ollama-models\ folder to
echo   each daughter's drive.
echo  ================================================
echo.
pause
