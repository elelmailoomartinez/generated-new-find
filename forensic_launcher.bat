@echo off
REM forensic_launcher.bat - simple launcher for Windows to run the PowerShell orchestrator
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0forensic_runner.ps1"
