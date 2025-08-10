<#  
    ┌─────────────────────────────────────────────────────────────┐
    │                         GREATON FORENSICS                   │
    │           MFT Extractor & Parser - Version 2.0 (PS)         │
    │                Contact: admin@greaton.co.uk                 │
    └─────────────────────────────────────────────────────────────┘

    License: MIT
    Description:
      - Resolves tool & output paths from the script’s own folder (no marker)
      - Parses NTFS $MFT via MFTECmd using a proper file path (e.g., C:\$MFT)
      - Optional: bounded raw $MFT dump for preservation
      - Optional: process all fixed NTFS volumes
      - Optional: VSS fallback if $MFT is locked
      - Timeout protection for MFTECmd
      - Logs actions and hashes outputs (including MFTECmd binary)
#>

[CmdletBinding()]
param(
    # Accepts "C:", "\\.\C:", or explicit "C:\$MFT". Ignored if -AllFixedVolumes is set.
    [string[]]$Target = @("\\.\C:"),

    # Process all fixed NTFS volumes found on the system
    [switch]$AllFixedVolumes,

    # Dump a bounded raw chunk of the $MFT (optional)
    [switch]$DumpRaw,

    # Size of raw dump in MiB when -DumpRaw is specified
    [int]$RawMiB = 256,

    # MFTECmd timeout (seconds)
    [int]$TimeoutSec = 300,

    # Attempt a VSS snapshot fallback if parsing direct $MFT fails (requires admin)
    [switch]$UseVssFallback
)

# ---------------- Helpers ----------------

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p  = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function New-DirectorySafe([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Write-Hash([string]$path) {
    if (Test-Path -LiteralPath $path) {
        $h = Get-FileHash -Algorithm SHA256 -LiteralPath $path
        "{0}  {1}" -f $h.Hash, $h.Path
    }
}

# Normalize input to both a drive letter (C:) and a metadata filepath (C:\$MFT)
function Resolve-MftTarget {
    param([string]$t)

    # Already a file path (ends with $MFT)? Use as-is.
    if ($t -match '\$MFT$') {
        $root = ([IO.Path]::GetPathRoot($t)).TrimEnd('\')
        if (-not $root) { throw "Invalid $MFT path: '$t'." }
        $drive = $root.TrimEnd(':') + ":"
        return [pscustomobject]@{
            Drive   = $drive
            MftPath = $t
            Volume  = "\\.\$($drive.TrimEnd(':')):"
        }
    }

    # Strip raw device prefix if present (\\.\C:)
    if ($t -match '^\\\\\.\\([A-Za-z]):') {
        $drive = ($Matches[1].ToUpper() + ":")
        return [pscustomobject]@{
            Drive   = $drive
            MftPath = "$drive\`$MFT"
            Volume  = "\\.\$($drive.TrimEnd(':')):"
        }
    }

    # Plain drive (C: style)
    if ($t -match '^[A-Za-z]:$') {
        $drive = $t.ToUpper()
        return [pscustomobject]@{
            Drive   = $drive
            MftPath = "$drive\`$MFT"
            Volume  = "\\.\$($drive.TrimEnd(':')):"
        }
    }

    throw "Unsupported Target: '$t'. Use C:, \\.\C:, or a full path like C:\$MFT"
}

# Read boot sector & compute $MFT offset, return stream + offset
function Get-MftOffsetInfo {
    param([string]$vol="\\.\C:")
    $fs = $null
    try {
        $fs = [System.IO.File]::Open($vol, 'Open', 'Read', 'ReadWrite')
        $boot = New-Object byte[] 512
        [void]$fs.Read($boot, 0, 512)

        $bps     = [BitConverter]::ToUInt16($boot, 11)  # Bytes per sector
        $spc     = $boot[13]                            # Sectors per cluster
        $mft_lcn = [BitConverter]::ToInt64($boot, 48)   # MFT LCN

        $clusterSize = [int64]$bps * [int64]$spc
        $mftOffset   = [int64]$mft_lcn * $clusterSize

        [pscustomobject]@{
            Stream    = $fs
            MftOffset = $mftOffset
        }
    } catch {
        if ($fs) { $fs.Dispose() }
        throw
    }
}

# Create (or reuse) a VSS snapshot for a given drive like 'C:'
function Get-OrCreate-VssSnapshotDevicePath {
    param([Parameter(Mandatory)] [string]$Drive)

    # Normalize 'C:' -> 'C:\'
    $driveRoot = ($Drive.TrimEnd('\') + '\')
    # Try to find an existing snapshot for this volume
    $existing = Get-CimInstance Win32_ShadowCopy -ErrorAction SilentlyContinue |
                Where-Object { $_.VolumeName -like "*$driveRoot*" } |
                Select-Object -First 1
    if (-not $existing) {
        $create = Invoke-CimMethod -ClassName Win32_ShadowCopy -MethodName Create -Arguments @{ Volume=$driveRoot; Context='ClientAccessible' } -ErrorAction Stop
        if ($create.ReturnValue -ne 0) { throw "VSS create failed with code $($create.ReturnValue)" }
        $existing = Get-CimInstance Win32_ShadowCopy -Filter "ID='$($create.ShadowID)'" -ErrorAction Stop
    }
    if (-not $existing.DeviceObject) { throw "VSS snapshot has no DeviceObject." }
    # DeviceObject usually like: \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopyXX
    return ($existing.DeviceObject.TrimEnd('\') + '\')
}

# Run MFTECmd with timeout; return $true if CSV produced
function Run-MFTECmd {
    param(
        [Parameter(Mandatory)] [string]$MFTECmdPath,
        [Parameter(Mandatory)] [string]$SourcePath,  # e.g., C:\$MFT or \\?\GLOBALROOT\...\$MFT
        [Parameter(Mandatory)] [string]$CsvDir,
        [Parameter(Mandatory)] [string]$CsvName,
        [int]$TimeoutSec = 300
    )

    $args = @("-f", $SourcePath, "--csv", $CsvDir, "--csvf", $CsvName) | ForEach-Object {
        if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $MFTECmdPath
    $psi.Arguments              = ($args -join ' ')
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
        try { $proc.Kill() } catch {}
        Write-Host "[!] MFTECmd timed out after $TimeoutSec seconds." -ForegroundColor Yellow
    }
    $outTask.Wait(); $errTask.Wait()
    $stdOut = $outTask.Result
    $stdErr = $errTask.Result
    if ($stdOut) { Write-Host $stdOut }
    if ($stdErr) { Write-Host $stdErr }

    Test-Path -LiteralPath (Join-Path $CsvDir $CsvName)
}

# Process a single resolved target (Drive/MftPath/Volume)
function Process-Target {
    param(
        [Parameter(Mandatory)] $Tgt,         # object from Resolve-MftTarget
        [Parameter(Mandatory)] [string]$ToolRoot,
        [Parameter(Mandatory)] [string]$MFTECmdPath,
        [Parameter(Mandatory)] [string]$OutputDir,
        [Parameter(Mandatory)] [string]$LogsDir,
        [switch]$DumpRaw,
        [int]$RawMiB = 256,
        [int]$TimeoutSec = 300,
        [switch]$UseVssFallback
    )

    $sys      = $env:COMPUTERNAME
    $ts       = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $drvTag   = $Tgt.Drive.TrimEnd(':')  # e.g., 'C'
    $csvName  = "$sys-$drvTag-$ts-MFT.csv"
    $csvFull  = Join-Path $OutputDir $csvName
    $rawName  = "$sys-$drvTag-$ts-MFT.raw.bin"
    $rawFull  = Join-Path $OutputDir $rawName
    $logPath  = Join-Path $LogsDir "$sys-$drvTag-$ts.log"

    try { Start-Transcript -Path $logPath -Append -ErrorAction Stop | Out-Null } catch {}

    Write-Host ""
    Write-Host "=== Volume $($Tgt.Drive) ===" -ForegroundColor Cyan
    Write-Host "[*] MFT path       : $($Tgt.MftPath)"
    Write-Host "[*] Volume (raw)   : $($Tgt.Volume)"

    # Optional raw dump
    $rawDumpDone = $false
    if ($DumpRaw) {
        try {
            Write-Host "[*] Calculating MFT offset from boot sector..."
            $info = Get-MftOffsetInfo -vol $Tgt.Volume
            $fs   = $info.Stream

            [void]$fs.Seek($info.MftOffset, 'Begin')
            $bytesToRead = [int64]$RawMiB * 1MB
            $buffer      = New-Object byte[] $bytesToRead

            Write-Host "[*] Reading $RawMiB MiB from MFT offset $($info.MftOffset)..."
            $totalRead = 0
            while ($totalRead -lt $bytesToRead) {
                $chunk = [int][Math]::Min(4MB, $bytesToRead - $totalRead)
                $read  = $fs.Read($buffer, $totalRead, $chunk)
                if ($read -le 0) { break }
                $totalRead += $read
            }
            $fs.Dispose()

            if ($totalRead -gt 0) {
                # Quick signature hint (not authoritative)
                $sig = [System.Text.Encoding]::ASCII.GetString($buffer, 0, [Math]::Min(4,$totalRead))
                if ($sig -ne "FILE") {
                    Write-Host "[!] Warning: MFT 'FILE' signature not found at computed offset." -ForegroundColor Yellow
                }

                [System.IO.File]::WriteAllBytes($rawFull, $buffer[0..($totalRead-1)])
                Write-Host "[+] Raw MFT chunk saved: $rawFull ($totalRead bytes)" -ForegroundColor Green

                if ($h = Write-Hash -path $rawFull) { Write-Host "[#] SHA256: $h" }
                $rawDumpDone = $true
            } else {
                Write-Host "[!] No data read at MFT offset; raw dump skipped." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "[!] Raw dump failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # MFTECmd direct parse
    Write-Host "[*] Running MFTECmd parse..."
    $ok = Run-MFTECmd -MFTECmdPath $MFTECmdPath -SourcePath $Tgt.MftPath -CsvDir $OutputDir -CsvName $csvName -TimeoutSec $TimeoutSec

    if ($ok) {
        Write-Host "[+] Parsed CSV created: $csvFull" -ForegroundColor Green
        if ($h = Write-Hash -path $csvFull) { Write-Host "[#] SHA256: $h" }
    } else {
        Write-Host "[!] MFTECmd did not produce expected CSV." -ForegroundColor Red

        # Try fallback from raw chunk if available
        if ($rawDumpDone) {
            Write-Host "[*] Attempting fallback parse from raw chunk..."
            $ok2 = Run-MFTECmd -MFTECmdPath $MFTECmdPath -SourcePath $rawFull -CsvDir $OutputDir -CsvName $csvName -TimeoutSec $TimeoutSec
            if ($ok2) {
                Write-Host "[+] Fallback parse created: $csvFull" -ForegroundColor Green
                if ($h = Write-Hash -path $csvFull) { Write-Host "[#] SHA256: $h" }
            } else {
                Write-Host "[!] Fallback parse failed as well." -ForegroundColor Red
            }
        }

        # Try VSS fallback if requested and still no CSV
        if ($UseVssFallback -and -not (Test-Path -LiteralPath $csvFull)) {
            try {
                Write-Host "[*] Attempting VSS fallback..." -ForegroundColor Yellow
                $snapRoot = Get-OrCreate-VssSnapshotDevicePath -Drive $Tgt.Drive
                $snapMft  = (Join-Path $snapRoot '$MFT')
                Write-Host "[*] Snapshot path: $snapMft"
                $ok3 = Run-MFTECmd -MFTECmdPath $MFTECmdPath -SourcePath $snapMft -CsvDir $OutputDir -CsvName $csvName -TimeoutSec $TimeoutSec
                if ($ok3) {
                    Write-Host "[+] VSS fallback parse created: $csvFull" -ForegroundColor Green
                    if ($h = Write-Hash -path $csvFull) { Write-Host "[#] SHA256: $h" }
                } else {
                    Write-Host "[!] VSS fallback parse failed." -ForegroundColor Red
                }
            } catch {
                Write-Host "[!] VSS fallback error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    try { Stop-Transcript | Out-Null } catch {}
}

# --------------- Pre-flight ---------------

if (-not (Test-IsAdmin)) {
    Write-Host "[!] Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Resolve script folder (works across PS versions)
$toolRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent -LiteralPath $MyInvocation.MyCommand.Path }
if (-not (Test-Path -LiteralPath $toolRoot)) {
    Write-Host "[!] Could not resolve tool root from script path." -ForegroundColor Red
    exit 1
}
try {
    $driveRoot = (Get-Item -LiteralPath $toolRoot).PSDrive.Root.TrimEnd('\')
} catch {
    $driveRoot = ""
}

$mfteCmdPath = Join-Path $toolRoot "MFTECmd\MFTECmd.exe"
$outputDir   = Join-Path $toolRoot "Output"
$logsDir     = Join-Path $toolRoot "Logs"
New-DirectorySafe $outputDir
New-DirectorySafe $logsDir

if (-not (Test-Path -LiteralPath $mfteCmdPath)) {
    Write-Host "[!] MFTECmd.exe not found at $mfteCmdPath" -ForegroundColor Red
    exit 1
}

# One-off: hash the MFTECmd binary
Write-Host "[#] MFTECmd path  : $mfteCmdPath"
if ($hbin = Write-Hash -path $mfteCmdPath) { Write-Host "[#] MFTECmd SHA256: $hbin" }

if ($driveRoot) { Write-Host "[*] Drive root     : $driveRoot" }
Write-Host "[*] Tool root      : $toolRoot"
Write-Host "[*] Output dir     : $outputDir"
Write-Host "[*] Logs dir       : $logsDir"
Write-Host ""

# --------------- Determine targets ---------------

$tgtList = @()
if ($AllFixedVolumes) {
    $drives = Get-Volume -ErrorAction SilentlyContinue |
              Where-Object { $_.DriveType -eq 'Fixed' -and $_.FileSystem -eq 'NTFS' -and $_.DriveLetter } |
              Select-Object -ExpandProperty DriveLetter
    if (-not $drives) {
        Write-Host "[!] No NTFS fixed volumes found." -ForegroundColor Yellow
        exit 1
    }
    foreach ($d in $drives) {
        try { $tgtList += (Resolve-MftTarget -t ("{0}:" -f $d)) } catch { Write-Host "[!] Skip $d`: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
} else {
    foreach ($t in $Target) {
        try { $tgtList += (Resolve-MftTarget -t $t) } catch { Write-Host "[!] Skip target '$t': $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}

if (-not $tgtList) {
    Write-Host "[!] No valid targets to process." -ForegroundColor Red
    exit 1
}

# --------------- Process targets ---------------

foreach ($tgt in $tgtList) {
    Process-Target -Tgt $tgt -ToolRoot $toolRoot -MFTECmdPath $mfteCmdPath -OutputDir $outputDir -LogsDir $logsDir `
        -DumpRaw:$DumpRaw -RawMiB $RawMiB -TimeoutSec $TimeoutSec -UseVssFallback:$UseVssFallback
}

Write-Host ""
Write-Host "[*] All done."
