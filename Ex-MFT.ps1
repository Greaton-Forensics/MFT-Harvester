<#
    ██████╗ ██████╗ ███████╗ █████╗ ████████╗ ██████╗ ███╗   ██╗    ███████╗ ██████╗ ██████╗ 
    ██╔══██╗██╔══██╗██╔════╝██╔══██╗╚══██╔══╝██╔═══██╗████╗  ██║    ██╔════╝██╔═══██╗██╔══██╗
    ██████╔╝██████╔╝█████╗  ███████║   ██║   ██║   ██║██╔██╗ ██║    █████╗  ██║   ██║██████╔╝
    ██╔═══╝ ██╔══██╗██╔══╝  ██╔══██║   ██║   ██║   ██║██║╚██╗██║    ██╔══╝  ██║   ██║██╔═══╝ 
    ██║     ██║  ██║███████╗██║  ██║   ██║   ╚██████╔╝██║ ╚████║    ██║     ╚██████╔╝██║     
    ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝    ╚═╝      ╚═════╝ ╚═╝     

    Greaton Forensics – MFT Extractor & Parser
    Email: Admin@greaton.co.uk
    Version: 1.0
    Author: Greaton Digital Security Team
    License: MIT (for script usage)
#>

<#
.SYNOPSIS
    Extracts the NTFS Master File Table (MFT) from the C: drive and parses it into a CSV using MFTECmd.
.DESCRIPTION
    Designed for USB-based incident response and forensic triage. The script saves a raw MFT dump and creates
    a timestamped, machine-named CSV report for further analysis.
.NOTES
    - Must be run as Administrator.
    - Output saved to H:\MFT-Capturer\[MFT_dump.bin, COMPUTERNAME-YYYY-MM-DD-MFT.csv]
    - Requires MFTECmd.exe (not included).
#>

# Parameters
$volume = "\\.\C:"
$usbRoot = "H:\MFT-Capturer"
$outputRaw = Join-Path $usbRoot "MFT_dump.bin"
$mfteCmdPath = Join-Path $usbRoot "MFTECmd\MFTECmd.exe"

# Get timestamp and system name
$systemName = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd"
$outputCsvName = "$systemName-$timestamp-MFT.csv"
$outputCsvDir = $usbRoot
$csvFullPath = Join-Path $outputCsvDir $outputCsvName

# Ensure USB output directory exists
if (-not (Test-Path $usbRoot)) {
    Write-Host "[!] USB drive or target directory not found: $usbRoot" -ForegroundColor Red
    exit 1
}

# Try to open volume
try {
    $fs = [System.IO.File]::Open($volume, 'Open', 'Read', 'ReadWrite')
} catch {
    Write-Host "[!] Failed to open volume $volume. Run as Administrator." -ForegroundColor Red
    exit 1
}

# Read NTFS Boot Sector (first 512 bytes)
$bootSector = New-Object byte[] 512
$fs.Read($bootSector, 0, 512) | Out-Null

# Parse boot sector values
$bps = [BitConverter]::ToUInt16($bootSector, 11)
$spc = [BitConverter]::ToUInt16($bootSector, 13)
$mft_lcn = [BitConverter]::ToInt64($bootSector, 48)

$clusterSize = $bps * $spc
$mftOffset = $mft_lcn * $clusterSize

# Seek to MFT start
$fs.Seek($mftOffset, 'Begin') | Out-Null

# Read 100MB of MFT
$mftData = New-Object byte[] (1024 * 1024 * 100)
$fs.Read($mftData, 0, $mftData.Length) | Out-Null
$fs.Close()

# Write raw MFT to file
[System.IO.File]::WriteAllBytes($outputRaw, $mftData)
Write-Host "[+] MFT extracted to $outputRaw" -ForegroundColor Green

# Check if MFTECmd exists
if (-not (Test-Path $mfteCmdPath)) {
    Write-Host "[!] MFTECmd.exe not found at $mfteCmdPath" -ForegroundColor Red
    exit 1
}

# Run MFTECmd to convert to timestamped CSV
& $mfteCmdPath -f $outputRaw --csv $outputCsvDir --csvf $outputCsvName

if (Test-Path $csvFullPath) {
    Write-Host "[+] Parsed CSV created at $csvFullPath" -ForegroundColor Green
} else {
    Write-Host "[!] MFTECmd failed to generate CSV" -ForegroundColor Red
}
