#!/bin/bash
# This script installs the software as a service.

BASE_DIR="$(pwd -P)"

# If a Python virtual environment is already active, exit (deactivate) it.
# This prevents nesting venvs or installing into the wrong environment.
if [ -n "${VIRTUAL_ENV:-}" ]; then
  deactivate
fi

# Install the systemd service file.
cd $BASE_DIR/services
DEST_DIR="/etc/systemd/system"

echo "Installing 'bme-publisher' service"
#cp ./bme-publisher.service "$DEST_DIR/bme-publisher.service"
sudo install -m 0644 $BASE_DIR/services/bme-publisher.service /etc/systemd/system/bme-publisher.service

echo "Installing 'bme-collector' service"
#cp ./bme-collector.service "$DEST_DIR/bme-collector.service"
sudo install -m 0644 $BASE_DIR/services/bme-collector.service /etc/systemd/system/bme-collector.service
  
sudo systemctl daemon-reload
echo "!!ATTENTION: Services are not enabled! Please enable them manually..."
