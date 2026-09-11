# Windows Dependency & Setup Guide

> **A comprehensive guide for developers on Windows 10/11 to install all required dependencies, compilers, database engines, and runtime utilities for building and running PARAKH.**

---

## 1. Quick Install via Windows Package Manager (`winget`)

If you are running Windows 10 (version 1809+) or Windows 11, open an **Administrator PowerShell** terminal and execute the following one-liner to install all necessary tooling:

```powershell
winget install --id Rustlang.Rustup -e ; `
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" ; `
winget install --id PostgreSQL.PostgreSQL -e ; `
winget install --id Git.Git -e ; `
winget install --id OpenJS.NodeJS.LTS -e ; `
winget install --id pnpm.pnpm -e ; `
winget install --id jqlang.jq -e
```

*After installation, close and reopen your PowerShell window to refresh system `PATH` variables.*

---

## 2. Tool-by-Tool Detailed Installation Guide & Links

### 1. Microsoft C++ Build Tools (MSVC Compiler)
* **Why it's required:** The `themis` backend compiles native Rust code and links against C-libraries (ONNX Runtime C-API and `sqlx` TLS drivers). The MSVC C++ linker is strictly required on Windows.
* **Official Download:** [Visual Studio C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
* **Winget Command:**
  ```powershell
  winget install --id Microsoft.VisualStudio.2022.BuildTools -e
  ```
* **Installation Checklist:**
  - Launch the Visual Studio Installer.
  - Check the workload: **"Desktop development with C++"**.
  - Ensure **MSVC v143 - VS 2022 C++ x64/x86 build tools** and **Windows 10/11 SDK** are selected.
  - Click **Install** (~1.5 GB).

---

### 2. Rust Toolchain (`rustup` & `cargo`)
* **Why it's required:** Compiles the high-performance PARAKH engine.
* **Official Download:** [rustup.rs](https://rustup.rs/) (Download `rustup-init.exe` 64-bit).
* **Winget Command:**
  ```powershell
  winget install --id Rustlang.Rustup -e
  ```
* **Post-Install Verification:**
  Open a new PowerShell terminal and verify:
  ```powershell
  rustc --version
  cargo --version
  ```
  *(Expected: `rustc 1.85+` or `1.97+`)*

---

### 3. PostgreSQL Database Engine (v16 or v17)
* **Why it's required:** Stores historical product inspections, bounding box coordinates, and compliance audit statistics.
* **Official Download (EnterpriseDB):** [PostgreSQL for Windows Official Downloads](https://www.enterprisedb.com/downloads/postgres-postgresql-downloads)
* **Winget Command:**
  ```powershell
  winget install --id PostgreSQL.PostgreSQL -e
  ```
* **Configuration Steps:**
  1. During the installation wizard:
     - Set superuser password (e.g. `postgres` or your preferred password).
     - Default port: `5432`.
     - Default locale: `[Default locale]`.
  2. Launch **pgAdmin 4** (included in the install) or open PowerShell and create the `themis` database:
     ```powershell
     # Using psql in PowerShell (adjust path if needed):
     & "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -c "CREATE DATABASE themis;"
     ```
  3. Connection String format for PARAKH:
     ```
     postgres://postgres:<your_password>@localhost:5432/themis
     ```

---

### 4. Git for Windows
* **Why it's required:** Version control, cloning the repository, and handling Git hooks.
* **Official Download:** [git-scm.com/download/win](https://git-scm.com/download/win)
* **Winget Command:**
  ```powershell
  winget install --id Git.Git -e
  ```

---


---

### 5. Utility Tools (Optional but Recommended)
* **Windows Terminal:** Modern tabbed terminal.
  ```powershell
  winget install --id Microsoft.WindowsTerminal -e
  ```
* **`jq` (Command-Line JSON Processor):** Useful for parsing API responses in PowerShell.
  ```powershell
  winget install --id jqlang.jq -e
  ```
* **`curl`:** Built directly into Windows 10/11 (`curl.exe`).

---

## 3. How ONNX Runtime Works on Windows

* PARAKH uses the `ort` crate (`v2.0.0-rc.13`).
* **Zero Manual Setup:** On Windows MSVC targets, the `ort` crate automatically downloads the official precompiled `onnxruntime.dll` release from Microsoft and bundles it directly with the executable.
* You do **not** need to manually build ONNX Runtime or install CUDA. The CPU execution provider runs out of the box with AVX2/AVX-512 SIMD vectorization.

---

## 4. Building & Running PARAKH on Windows

### Step 1: Clone Repository
```powershell
git clone https://github.com/vedantdubal-141/PARAKH.git
cd PARAKH
```

### Step 2: Configure Environment Variables
In PowerShell:
```powershell
$env:DATABASE_URL = "postgres://postgres:yourpassword@localhost:5432/themis"
```
*(Replace `yourpassword` with your local PostgreSQL password).*

### Step 3: Compile the Optimized Release Binary
```powershell
cargo build --release --manifest-path themis/Cargo.toml
```
*The compilation takes ~30–60 seconds on the first run, producing `themis\target\release\themis.exe` (~25 MB).*

### Step 4: Run the Backend Daemon
```powershell
.\themis\target\release\themis.exe --port 8080
```
**Expected Output:**
```
INFO themis: ⚖️  Starting PARAKH Legal Metrology Compliance Engine (CPU Mode)
INFO themis::ocr::pipeline: Using PP-OCRv4 SERVER detection model (high-accuracy)
INFO themis::ocr::pipeline: Initializing PARAKH OCR pipeline on CPU... dir=themis/models
INFO themis::ocr::detector: Loading PP-OCR DBNet detection model on CPU...
INFO themis::ocr::recognizer: Loading PP-OCRv4 recognition model on CPU...
INFO themis: Connecting to PostgreSQL database at postgres://postgres:***@localhost:5432/themis...
INFO themis: PostgreSQL connected successfully.
INFO themis::db::repo: PostgreSQL schema initialized successfully.
INFO themis: 🚀 PARAKH REST API listening on http://0.0.0.0:8080
```

### Step 5: Test from PowerShell
In a separate PowerShell window:
```powershell
# Health check:
curl.exe -s http://localhost:8080/api/v1/health

# Query historical stats:
curl.exe -s http://localhost:8080/api/v1/stats
```
