@echo off
setlocal EnableDelayedExpansion
title Building Installer...
cd /d "%~dp0"

echo.
echo  ================================================
echo   Building "Install Dad's App.exe"
echo  ================================================
echo.

:: ── Step 1: Build Talk to Dad.exe ───────────────────────────────────────────
if not exist "dist\Talk to Dad.exe" (
    echo  Building Talk to Dad.exe...
    pyinstaller --onefile --noconsole --name "Talk to Dad" --hidden-import requests talk_to_dad.py
    if errorlevel 1 ( echo  PyInstaller failed. & pause & exit /b 1 )
    echo  EXE built.
) else (
    echo  Talk to Dad.exe already built, skipping.
)

:: ── Step 2: Download Ollama installer ────────────────────────────────────────
if not exist "OllamaSetup.exe" (
    echo  Downloading Ollama installer...
    powershell -NoProfile -Command ^
        "Invoke-WebRequest -Uri 'https://github.com/ollama/ollama/releases/latest/download/OllamaSetup.exe' -OutFile 'OllamaSetup.exe' -UseBasicParsing"
    if errorlevel 1 ( echo  Download failed. Check internet connection. & pause & exit /b 1 )
    echo  Ollama installer downloaded.
) else (
    echo  OllamaSetup.exe already present, skipping.
)

:: ── Step 3: Find Inno Setup ──────────────────────────────────────────────────
call :FindISCC
if "!ISCC!"=="" (
    echo  Inno Setup not found. Installing...
    powershell -NoProfile -Command ^
        "Invoke-WebRequest -Uri 'https://files.jrsoftware.org/is/6/innosetup-6.4.3.exe' -OutFile '%TEMP%\innosetup.exe' -UseBasicParsing; Start-Process '%TEMP%\innosetup.exe' -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Wait"
    call :FindISCC
)

if "!ISCC!"=="" (
    echo.
    echo  Could not find ISCC.exe after installation.
    echo  Please install Inno Setup manually from https://jrsoftware.org/isdl.php
    echo  then run this script again.
    pause
    exit /b 1
)

:: ── Step 4: Compile installer ────────────────────────────────────────────────
echo  Using: !ISCC!
echo  Compiling installer...
"!ISCC!" installer.iss
if errorlevel 1 ( echo  Compile failed. & pause & exit /b 1 )

echo.
echo  ================================================
echo   Done!
echo.
echo   Installer: Output\Install Dad's App.exe
echo.
echo   Put this file + the ollama-models\ folder
echo   on each daughter's drive.
echo  ================================================
echo.
pause
exit /b 0


:: ── Subroutine: locate ISCC.exe ──────────────────────────────────────────────
:FindISCC
set ISCC=
:: Check common install paths
for %%p in (
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    "C:\Program Files\Inno Setup 6\ISCC.exe"
) do ( if exist %%p ( set "ISCC=%%~p" & goto :eof ) )

:: Check registry for install location
for %%k in (
    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1"
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1"
) do (
    for /f "tokens=2*" %%a in (
        'reg query %%k /v InstallLocation 2^>nul'
    ) do (
        if exist "%%b\ISCC.exe" ( set "ISCC=%%b\ISCC.exe" & goto :eof )
    )
)
goto :eof
