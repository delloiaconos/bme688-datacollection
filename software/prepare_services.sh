#!/bin/bash
# This script prepares the software for installation as a service.

BASE_DIR="$(pwd -P)"
DEST_DIR="/opt/bme"

# If a Python virtual environment is already active, exit (deactivate) it.
# This prevents nesting venvs or installing into the wrong environment.
if [ -n "${VIRTUAL_ENV:-}" ]; then
  deactivate
fi

# Create the target installation directory under /opt.
sudo mkdir -p "$DEST_DIR"
sudo chown "$(id -un):$(id -gn)" "$DEST_DIR"

# Copy all helper scripts/resources from the local ./scripts directory
# into the installation directory.
cp -r $BASE_DIR/scripts/* "$DEST_DIR/"

# Build the project from source and copy the binary to destination.
cd "$BASE_DIR/bme688-linux"
make clean
make all
cp "$BASE_DIR/bme688-linux/out/bme-grabber" "$DEST_DIR/"
# Ensure executable permission.
chmod +x "$DEST_DIR/bme-grabber"

# Move into the installation directory
cd "$DEST_DIR"

# Create a Python virtual environment named and install requirements
python3 -m venv env
source env/bin/activate
pip install -r requirements.txt

rm requirements.txt