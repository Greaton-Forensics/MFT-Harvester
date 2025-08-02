# 🧰 MFT-Forensic-Extractor
A plug-and-play PowerShell forensic utility for extracting and parsing the NTFS Master File Table (MFT) from Windows systems.  
Designed for incident response, triage, and digital forensic investigations.

---

## 📜 Disclaimer
This script is intended to automate the extraction and analysis of the NTFS MFT for lawful forensic purposes.

> ⚠️ **Important:**  
> This project uses [MFTECmd](https://ericzimmerman.github.io/) by **Eric Zimmerman** for MFT parsing.  
> MFTECmd is not included in this repository. You must download it separately from the official source.  
> This project does **not** modify, bundle, or distribute MFTECmd.

---

## 🔍 Overview
This tool is designed to be run from a USB stick. It automatically extracts the MFT from the `C:` drive and uses MFTECmd to create a timestamped CSV report named after the host machine.

---

## 🎯 Purpose
The main goal is to provide:

- ✅ A portable forensic utility for live triage  
- ✅ Stealthy execution from USB without installation  
- ✅ Structured and timestamped MFT data extraction  

Ideal for blue teams, IR responders, and forensic analysts needing quick field access.

---

## 🔑 Key Features

- ✔️ **USB-Ready** – Plug-and-play compatible  
- ✔️ **Dynamic Naming** – Outputs `COMPUTERNAME-YYYY-MM-DD-MFT.csv`  
- ✔️ **MFT Dump** – Extracts 100MB of the raw MFT  
- ✔️ **Clean CSV Output** – Uses MFTECmd for parsing  
- ✔️ **Privilege Checks** – Confirms admin rights before execution  
- ✔️ **Failsafe Logic** – Validates paths and tool presence  

---

## ⚙️ Requirements

- 🧩 **PowerShell 5.1 or higher**  
- 🔐 **Administrator privileges**  
- 💾 **USB/External Drive with this structure:**

```
H:\
└── MFT-Capturer\
    ├── Ex-MFT.ps1
    └── MFTECmd\
        └── MFTECmd.exe
```

---

## 🛠️ How to Use

1. 📥 Clone or download this repo.  
2. 🧷 Place `Ex-MFT.ps1` on your USB at: `H:\MFT-Capturer`  
3. 📂 Place `MFTECmd.exe` at: `H:\MFT-Capturer\MFTECmd\MFTECmd.exe`  
4. ▶️ Run the script as **Administrator** on the target system.

### 🔄 What It Does

- Extracts the MFT from `C:` into `MFT_dump.bin`  
- Runs MFTECmd to parse it into a `.csv` file  
- Output is named: `COMPUTERNAME-YYYY-MM-DD-MFT.csv`  

---

## 💻 Example Output

```
H:\MFT-Capturer\
├── Ex-MFT.ps1
├── MFT_dump.bin
├── GREATON-2025-08-02-MFT.csv
└── MFTECmd\
    └── MFTECmd.exe
```

---

## 🧪 Tested On

- ✅ Windows 10  
- ✅ Windows 11  
- ✅ NTFS system volumes only  
- ✅ PowerShell 5.1+

---

## 📁 Suggested Repository Structure

```
MFT-Capturer/
├── Ex-MFT.ps1
├── README.md
├── Run-MFT-Tool.bat (optional)
└── MFTECmd/
    └── MFTECmd.exe
```

---

## 📬 Contact

**Greaton Forensics**  
📧 Email: [admin@greaton.co.uk](mailto:admin@greaton.co.uk)

---

## 🪪 License

This script is provided under the [MIT License](https://opensource.org/licenses/MIT).  
MFTECmd is not part of this project and is licensed separately by its creator.
