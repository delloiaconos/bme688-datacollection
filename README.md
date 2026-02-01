# Bosch BME688 Raspberry Pi Data Logger (Custom PCB)

This repository provides a complete workflow to collect sensor data from a **Bosch Sensortec BME688 Development Board** connected to a **Raspberry Pi**.  
It includes the required source code (and/or submodules) and step-by-step instructions to configure the Raspberry Pi and start logging measurements.

---

## Project Overview

### Required Hardware
- Bosch Sensortec **BME688 Development Board**
- Raspberry Pi (tested on: Pi 3B+ / Pi 4)
- Custom PCB adapter or connection

### Project Contents 
- Raspberry Pi setup guide (dependencies, permissions)
- Data acquisition software and additional scripts
- Optional submodules for third-party drivers/libraries

---

## Repository Structure

```
.
├── README.md
├── docs/
│   ├── setup.md
│   └── connections.md
├── hardware/
│   └── pcb/                       # schematics, gerbers, CAD, etc.
├── software/
│   ├── logger/                    # main acquisition application
│   ├── drivers/                   # vendor/third-party drivers (or submodule)
│   ├── scripts/                   # run helpers, service installer, etc.
│   └── README.md                  # build/run details (if needed)
└── .gitmodules                    # git submodules 
```

> If your repository uses different folders, update this section to match your layout.

---

## Quick Start

### 1) Clone the repository (including submodules)

```bash
git clone --recurse-submodules https://github.com/delloiaconos/bme688-datacollection.git
cd bme688-datacollection
```

If you already cloned without submodules:
```bash
git submodule update --init --recursive
```

---

### 2) Configure Raspberry Pi (I²C)

Enable I²C:
```bash
sudo raspi-config
```
Navigate to: **Interface Options → I2C → Enable**

Reboot:
```bash
sudo reboot
```

After reboot, verify the I²C device nodes exist:
```bash
ls /dev/i2c-*
```

Install I²C tools (useful for debugging):
```bash
sudo apt update
sudo apt install -y i2c-tools
```

Detect the sensor (common bus is `i2c-1`):
```bash
sudo i2cdetect -y 1
```

You should see the TCA6408A address appear (address `0x20`).

---

### 3) Install dependencies

#### C/C++ Development suite
```bash
sudo apt update
sudo apt install -y build-essential cmake
```

### 4) Build & Run

```bash
cd software/bme688-linux

make all
```

Example run:
```bash
./bme688_logger 
```

---

## Output Data

---

## Raspberry Pi Auto-Start (Optional)

If you want the logger to start on boot, this repository can include a `systemd` service installer.

Example (if provided):
```bash
sudo bash software/scripts/install_service.sh
sudo systemctl enable bme688-logger
sudo systemctl start bme688-logger
sudo systemctl status bme688-logger
```

---

## Documentation

- **Raspberry Pi setup:** `docs/setup.md`
- **Custom PCB wiring/connection map:** `docs/connections.md` (or `hardware/pcb/`)
- **Notes:** `docs/notes.md`
- **Troubleshooting:** `docs/troubleshooting.md`

---

## License

Add your license here (e.g., MIT, BSD-3-Clause, GPL-3.0) and include a `LICENSE` file.

---
