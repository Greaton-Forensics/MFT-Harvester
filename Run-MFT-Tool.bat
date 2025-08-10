@echo off
:: ┌─────────────────────────────────────────────────────────────┐
:: │                    GREATON FORENSICS                        │
:: │      MFT-Harvester Batch Launcher - Version 2.7              │
:: │          Contact: admin@greaton.co.uk                        │
:: └─────────────────────────────────────────────────────────────┘

:: Save as: Run-MFT-Tool.bat in H:\MFT-Capturer

setlocal ENABLEDELAYEDEXPANSION

:: Prefer 64-bit PowerShell even from 32-bit contexts
set "POWERSHELL=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL%" set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

set "SCRIPT=%~dp0Ex-MFT.ps1"
set "MFTECMD=%~dp0MFTECmd\MFTECmd.exe"

:: Banner
echo ============================================================
echo   GREATON FORENSICS
echo   MFT-Harvester Batch Launcher - Version 2.7
echo   Contact: admin@greaton.co.uk
echo ============================================================

:: Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [*] Requesting administrative privileges...
    "%POWERSHELL%" -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Check files exist
if not exist "%SCRIPT%" (
    echo [!] ERROR: Ex-MFT.ps1 not found at "%SCRIPT%"
    pause
    exit /b 1
)
if not exist "%MFTECMD%" (
    echo [!] ERROR: MFTECmd.exe not found at "%MFTECMD%"
    echo     Please place MFTECmd.exe in the MFTECmd folder.
    pause
    exit /b 1
)

:: Display MFTECmd SHA256
for /f "delims=" %%A in ('"%POWERSHELL%" -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -Path ''%MFTECMD%'').Hash"') do set "HASH=%%A"
echo [#] MFTECmd path  : %MFTECMD%
echo [#] MFTECmd SHA256: %HASH%

:: Run PowerShell script with recommended parameters
echo [*] Running Ex-MFT.ps1 with All Fixed Volumes, VSS Fallback, and 512MiB raw fallback chunk...
"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -AllFixedVolumes -UseVssFallback -RawMiB 512 -TimeoutSec 600

pause
