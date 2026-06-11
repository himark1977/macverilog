# 🚀 MacVerilog — Native Verilog IDE & Waveform Viewer for macOS

MacVerilog is a lightweight, high-performance IDE built natively in SwiftUI for hardware engineers and students development on macOS. It eliminates the need for resource-heavy Linux VMs, Docker containers, or wine layers, providing a clean, "Apple-level" integrated experience for behavioral simulation and VCD analysis.

<img width="1196" height="775" alt="MacVerilog Workspace" src="https://github.com/user-attachments/assets/0cd0b480-7817-44f0-8cfb-e573d285f524" />

## ✨ Features
* **Vivado-Style Hierarchy:** Clean sidebar project manager tailored for modular digital design.
* **Native VCD Waveform Viewer:** High-density, interactive digital signal plotting with automatic scaling.
* **Zero-Configuration Simulation:** Direct integration with open-source simulation backends.

---

## 🛠️ Prerequisites & Installation

MacVerilog relies on **Icarus Verilog (`iverilog`)** for compilation and the **`vvp`** runtime engine for simulation execution. 

### 1. Install Homebrew (If not already installed)
https://brew.sh

### 2. Install Icarus Verilog
Once Homebrew is configured, install the simulation toolchain by running:
Bash
```brew install icarus-verilog```
### 3. Verify Installation Paths
To ensure MacVerilog can locate the compiler binaries automatically, verify that your local environment paths match the outputs below:
```
% which iverilog
/opt/homebrew/bin/iverilog

% which vvp
/opt/homebrew/bin/vvp
```
Note: On Apple Silicon Macs (M1/M2/M3/M4), the standard prefix is /opt/homebrew/bin/.

### 🚀 Quick Start
Clone or download the stable release binarie.
Launch MacVerilog.app.
Open your .v workspace, write your behavioral testbench, and hit Run Simulation to view the live waveforms instantly.
