# Installation Instructions

## System Requirements

### C/C++ Development suite

```bash
sudo apt update
sudo apt install -y build-essential cmake
```

### SQLite3

This is needed only if you want to read locally generated files.

```bash
sudo apt install sqlite3
```

## Mosquitto

It is not needed to install mosquitto locally.

### Installation

```bash
sudo apt update
sudo apt install mosquitto mosquitto-clients
sudo systemctl enable mosquitto
```

### Basic configuration

To configure Mosquitto it is possible to edit the  configuration file (usually `/etc/mosquitto/mosquitto.conf`) or a new file in `/etc/mosquitto/conf.d/`.

```bash
# 1. Listen ONLY on the local loopback interface (localhost)
listener 1883 127.0.0.1

# 2. Allow connection without username/password
allow_anonymous true
```

In order to restart mosquitto, it is possible to run the following command:

```bash
sudo systemctl restart mosquitto
```

### Bridge configuration

In Mosquitto, _repeater_ functionality is achieved through **Bridging**. 
A bridge allows a local Mosquitto broker to connect to another remote broker as a client. 
It can then forward messages between the two based on specific rules.


The core logic is defined by the topic directive in the configuration file. 
This single line dictates what is sent, where it goes, and how reliably it travels.

The syntax for the repeater logic is:
```bash
topic <pattern> <direction> <QoS> <local-prefix> <remote-prefix>
```


```bash
# A name for this connection (can be anything)
connection remote-bridge

# The address of the REMOTE broker you want to send data to
address remote.broker.com:1883

# Credentials for the REMOTE broker (if needed)
remote_username my_remote_user
remote_password my_remote_password

# THE IMPORTANT PART: Traffic Rules
# Syntax: topic <pattern> <direction> <QoS> <local-prefix> <remote-prefix>

# 1. To "Repeat" everything from Local -> Remote
topic # out 0

# 2. To receive commands from Remote -> Local
# topic # in 0
```


## BME688 Logger

### Build

```bash
# Move to bme688 logger directory
cd software/bme688-linux

# Update submodules
git submodule update

# Compile the project
make 

# Copy executable
cp out/bme-logger ../

```

### Run 

Example run:
```bash
./bme-logger 
```
