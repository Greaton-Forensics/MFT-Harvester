MFT-Forensic-Extractor
=======================

A plug-and-play forensic tool to extract and parse the NTFS Master File Table (MFT) from Windows systems.
Run from a USB drive, this tool captures the raw MFT and converts it into a structured CSV using MFTECmd.

Folder Structure:
-----------------
- Ex-MFT.ps1           : PowerShell script to extract and parse MFT
- Run-MFT-Tool.bat     : Batch launcher (auto-elevates to Admin)
- MFTECmd/MFTECmd.exe  : Required binary for parsing MFT

Usage Instructions:
-------------------
1. Plug in your USB (e.g. H:) and ensure the structure above exists
2. Right-click Run-MFT-Tool.bat and select 'Run as Administrator'
3. The script will:
   - Extract the raw MFT to MFT_dump.bin
   - Use MFTECmd to generate COMPUTERNAME-YYYY-MM-DD-MFT.csv

Requirements:
-------------
- Must run as Administrator
- NTFS file system on C: drive
- MFTECmd.exe must be downloaded manually from ericzimmerman.github.io

License:
--------
MIT License (scripts only). MFTECmd licensed separately.
