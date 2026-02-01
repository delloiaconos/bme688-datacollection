#!/bin/bash

# If a Python virtual environment is already active, exit (deactivate) it.
# This prevents nesting venvs or installing into the wrong environment.
if [ -n "${VIRTUAL_ENV:-}" ]; then
  deactivate
fi

BASE_DIR="$(pwd -P)"

# This script installs the software as a service.

# Create the target installation directory under /opt.
mkdir -p /opt/bme

# Copy all helper scripts/resources from the local ./scripts directory
# into the installation directory.
cp -r $BASE_DIR/scripts/* /opt/bme/

# Build the project from source and copy the binary to destination.
cd $BASE_DIR/bme688-linux
make clean
make all
cp ./out/bme-logger /opt/bme/
# Ensure executable permission.
chmod +x /opt/bme/bme-logger


# Install the systemd service file.
cd $BASE_DIR/services
DEST_DIR="/etc/systemd/system"

echo "Installing 'stream-publisher' service"
#cp ./stream-publisher.service "$DEST_DIR/stream-publisher.service"
sudo install -m 0644 $BASE_DIR/services/bme-publisher.service /etc/systemd/system/bme-publisher.service


echo "Installing 'mqtt-collector' service"
#cp ./mqtt-collector.service "$DEST_DIR/mqtt-collector.service"
sudo install -m 0644 $BASE_DIR/services/bme-collector.service /etc/systemd/system/bme-collector.service
  
sudo systemctl daemon-reload
echo "!!ATTENTION: Services are not enabled! Please enable them manually..."

# Move into the installation directory
cd /opt/bme/

# Create a Python virtual environment named and install requirements
python3 -m venv env
source env/bin/activate
pip install -r requirements.txt
