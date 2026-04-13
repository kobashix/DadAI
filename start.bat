@echo off
title Talk to Dad

:: Start Ollama in background if not already running
ollama list >nul 2>&1
if errorlevel 1 (
    start /min "" ollama serve
    timeout /t 3 /nobreak >nul
)

:: Launch the chat GUI
python "%~dp0twin_chat.py"
