@echo off
:: GREATON FORENSICS - MFT-Harvester Launcher (plain ASCII)
:: Version: 1.3
:: Author : Greaton Digital Security Team
:: Contact: admin@greaton.co.uk

setlocal enableextensions
set "VERSION=1.3"
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Ex-MFT.ps1"
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

title MFT-Harvester v%VERSION% - Greaton Forensics
color 0A

echo.
echo ==============================================================
echo   GREATON FORENSICS - MFT-Harvester Launcher v%VERSION%
echo   Contact: admin@greaton.co.uk
echo ==============================================================

:: Verify script path
if not exist "%PS_SCRIPT%" (
  echo [!] Ex-MFT.ps1 not found at: "%PS_SCRIPT%"
  echo     Ensure this batch file sits next to Ex-MFT.ps1.
  pause
  exit /b 1
)

:: Admin check (net session requires admin)
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo [*] Requesting administrative privileges...
  "%POWERSHELL%" -NoProfile -Command ^
    "Start-Process -FilePath '%comspec%' -ArgumentList '/c \"\"%~f0\" %*\"' -Verb RunAs"
  exit /b
)

:: Run from script directory so relative paths work
pushd "%SCRIPT_DIR%" >nul

echo [*] Running Ex-MFT.ps1 with VSS fallback...
"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -UseVssFallback

set "RC=%ERRORLEVEL%"
popd >nul

echo.
echo [*] Process complete. Exit code: %RC%
pause
endlocal & exit /b %RC%
