#!/bin/bash
# This script prepares the software for installation as a service.

BASE_DIR="$(pwd -P)"

# If a Python virtual environment is already active, exit (deactivate) it.
# This prevents nesting venvs or installing into the wrong environment.
if [ -n "${VIRTUAL_ENV:-}" ]; then
  deactivate
fi

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


# Move into the installation directory
cd /opt/bme/

# Create a Python virtual environment named and install requirements
python3 -m venv env
source env/bin/activate
pip install -r requirements.txt
