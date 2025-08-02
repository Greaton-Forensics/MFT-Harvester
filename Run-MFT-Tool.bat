@echo off
:: Elevate to Administrator
:: Save this as Run-MFT-Tool.bat in H:\MFT-Capturer

set script=%~dp0Ex-MFT.ps1

:: Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%comspec%' -ArgumentList '/c %~f0' -Verb RunAs"
    exit /b
)

:: Run PowerShell script
echo Running Ex-MFT.ps1...
powershell -ExecutionPolicy Bypass -NoProfile -File "%script%"
pause
