@echo off
REM run_all.bat - launcher that downloads and runs forensic_runner.ps1 from the reponecho Downloading and running forensic_runner.ps1...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/elelmailoomartinez/generated-new-find/main/forensic_runner.ps1' -OutFile $env:TEMP\forensic_runner.ps1 -UseBasicParsing; & $env:TEMP\forensic_runner.ps1 } catch { Write-Error \"Failed to download/run forensic_runner.ps1: $_\"; exit 1 }"
