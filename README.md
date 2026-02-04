# Bosch BME688 Raspberry Pi Data Logger

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
├── docs/                          # documentation
├── hardware/
│   └── pcb/                       # schematics, gerbers, CAD, etc.
├── processing/                    # post processing scripts (mix of Python and MATLAB)
├── software/
│   ├── bme688-linux/              # main BME688 acquisition application (submodule)
│   ├── scripts/                   # python scripts, etc.
│   ├── services/                  # services description, etc.
│   └── install_services.sh        # Install all the services and requirements.
├── .gitignore                     # git ignore
└── .gitmodules                    # git submodules 
```

## Quick Start

### 1) Clone the repository (including submodules)

```bash
git clone --recurse-submodules https://github.com/delloiaconos/bme688-datacollection.git
```

If you already cloned without submodules, from `bme688-datacollection` directory:
```bash
git submodule update --init --recursive
```

### 2) Configure Raspberry Pi (I²C)

Enable I²C:
```bash
sudo raspi-config
```
Navigate to: 
- **Interface Options → I2C → Enable**
- **Interface Options → SPI → Enable**

You can also run a single command to enable the two interfaces:

```bash
sudo raspi-config nonint do_spi 0 
sudo raspi-config nonint do_i2c 0
```

To enable the interfaces it is needed a reboot:
```bash
sudo reboot
```

After reboot, verify the I²C device nodes exist:
```bash
ls /dev/i2c-*
```

It is recomended to install I²C tools (useful for debugging):
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

## Raspberry Pi Auto-Start (Optional)

If you want the logger to start on boot, this repository can include a `systemd` service installer.

Example:
```bash
cd software
sudo bash prepare_services.sh
sudo bash install_services.sh

sudo systemctl daemon-reload

#sudo systemctl enable bme-publisher
sudo systemctl start bme-publisher
sudo systemctl status bme-publisher

#sudo systemctl enable bme-collector
sudo systemctl start bme-collector
sudo systemctl status bme-collector
```

---

## Documentation

- **Raspberry Pi setup:** `docs/setup.md`
- **Notes:** `docs/notes.md`
- **Troubleshooting:** `docs/troubleshooting.md`

---

## License

Add your license here (e.g., MIT, BSD-3-Clause, GPL-3.0) and include a `LICENSE` file.

---
