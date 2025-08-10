# 🧰 MFT-Harvester
A plug-and-play PowerShell forensic utility for extracting and parsing the NTFS Master File Table (MFT) from Windows systems. Designed for incident response, triage, and digital forensic investigations.

## 📜 Disclaimer
This script is intended to automate the extraction and analysis of the NTFS MFT for lawful forensic purposes. Do not use on systems you do not have explicit permission to examine.

## ⚠️ Important
This project uses **MFTECmd** by Eric Zimmerman for MFT parsing.  
MFTECmd is **not included** in this repository. You must download it separately from the official source.  
This project does **not** modify, bundle, or distribute MFTECmd.  
Official site: https://ericzimmerman.github.io/#!index.md

## 🔍 Overview
This tool is designed to be run from a USB stick. It can automatically extract the `$MFT` from the **C: drive** or from **all NTFS fixed volumes**, and uses MFTECmd to create timestamped CSV reports named after the host machine and volume.

## 🎯 Purpose
The main goal is to provide:  
✅ A portable forensic utility for live triage  
✅ Stealthy execution from USB without installation  
✅ Structured and timestamped `$MFT` data extraction  
✅ Built-in fallback via VSS for locked volumes  
Ideal for blue teams, IR responders, and forensic analysts needing quick field access.

## 🔑 Key Features
- **USB-Ready** – Plug-and-play compatible  
- **Multi-Volume Support** – `-AllFixedVolumes` to process every NTFS fixed drive  
- **Dynamic Naming** – Outputs `COMPUTERNAME-DRIVELETTER-YYYY-MM-DD_HH-MM-SS-MFT.csv`  
- **Optional Raw Dump** – `-DumpRaw -RawMiB <size>` preserves part of the `$MFT` binary  
- **VSS Fallback** – `-UseVssFallback` for locked `$MFT` files  
- **Timeout Protection** – MFTECmd auto-terminates if it hangs (default 300s)  
- **Privilege Checks** – Confirms admin rights before execution  
- **Failsafe Logic** – Validates paths and tool presence  
- **Full Logging** – Per-drive transcript logs + SHA-256 hashes of outputs and MFTECmd binary

## ⚙️ Requirements
- 🧩 PowerShell 5.1 or higher  
- 🔐 Administrator privileges  
- 💾 USB/External Drive with this structure:
```
H:\
└── MFT-Capturer
    ├── Ex-MFT.ps1
    ├── Run-MFT-Tool.bat (optional)
    └── MFTECmd
        └── MFTECmd.exe
```

## 🛠️ How to Use
📥 Clone or download this repo.  
🧷 Place `Ex-MFT.ps1` on your USB at:
```
H:\MFT-Capturer\
```
📂 Place `MFTECmd.exe` at:
```
H:\MFT-Capturer\MFTECmd\MFTECmd.exe
```
▶️ Run the script as Administrator on the target system.

### Examples
```powershell
# Single volume (default C:)
powershell -ExecutionPolicy Bypass -NoProfile -File ".\Ex-MFT.ps1"

# All NTFS fixed volumes with a 512MiB raw chunk and VSS fallback
powershell -ExecutionPolicy Bypass -NoProfile -File ".\Ex-MFT.ps1" -AllFixedVolumes -DumpRaw -RawMiB 512 -UseVssFallback

# Single D: volume, raw dump 256MiB, 5 min timeout
powershell -ExecutionPolicy Bypass -NoProfile -File ".\Ex-MFT.ps1" -Target "D:" -DumpRaw -RawMiB 256 -TimeoutSec 300
```

## 🔄 What It Does
- Checks admin privileges and MFTECmd availability  
- (Optional) Captures a bounded raw chunk of `$MFT`  
- Parses `$MFT` with MFTECmd into a timestamped CSV  
- (Optional) Uses VSS snapshot fallback if direct read fails  
- Logs actions, tool hashes, and output hashes

## 💻 Example Output
```
H:\MFT-Capturer\
├── Ex-MFT.ps1
├── Output\
│   ├── GREATON-C-2025-08-10_20-15-03-MFT.csv
│   ├── GREATON-C-2025-08-10_20-15-03-MFT.raw.bin
│   ├── GREATON-D-2025-08-10_20-18-44-MFT.csv
│   └── ...
├── Logs\
│   ├── GREATON-C-2025-08-10_20-15-03.log
│   └── GREATON-D-2025-08-10_20-18-44.log
└── MFTECmd\
    └── MFTECmd.exe
```

## 🧪 Tested On
- ✅ Windows 10  
- ✅ Windows 11  
- ✅ NTFS system and data volumes only  
- ✅ PowerShell 5.1+

## 📁 Suggested Repository Structure
```
MFT-Capturer/
├── Ex-MFT.ps1
├── README.md
├── Run-MFT-Tool.bat   # Optional batch wrapper for auto-elevation
└── MFTECmd/
    └── MFTECmd.exe
```

## 📬 Contact
Greaton Forensics  
📧 Email: admin@greaton.co.uk

## 🪪 License
This script is provided under the MIT License.  
MFTECmd is not part of this project and is licensed separately by its creator.
