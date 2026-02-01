#!/bin/bash
#
# install_services.sh
# This script installs the BME688 data collection software as systemd services on Linux/Raspberry Pi.
#
# Usage:
#   sudo bash install_services.sh [--uninstall]
#
# Services created:
#   - bme688-logger.service: Reads BME688 sensor data and publishes to MQTT
#   - bme688-collector.service: Subscribes to MQTT and stores data in SQLite
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BME_LOGGER_PATH="$SCRIPT_DIR/bme-logger"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
PYTHON_PUBLISHER="$SCRIPTS_DIR/stream_publisher.py"
PYTHON_COLLECTOR="$SCRIPTS_DIR/mqtt_to_sqlite.py"
REQUIREMENTS_FILE="$SCRIPTS_DIR/requirements.txt"

# Systemd service paths
SYSTEMD_DIR="/etc/systemd/system"
LOGGER_SERVICE="bme688-logger.service"
COLLECTOR_SERVICE="bme688-collector.service"

# MQTT configuration (defaults)
MQTT_HOST="${MQTT_HOST:-127.0.0.1}"
MQTT_PORT="${MQTT_PORT:-1883}"
MQTT_TOPIC_PREFIX="${MQTT_TOPIC_PREFIX:-measures/$(hostname)}"

# Database configuration
DB_PATH="${DB_PATH:-$SCRIPT_DIR/measures.sqlite3}"

# Working user (defaults to current user if not root, or 'pi' if root)
if [ "$EUID" -eq 0 ]; then
    SERVICE_USER="${SERVICE_USER:-pi}"
else
    SERVICE_USER="${SERVICE_USER:-$USER}"
fi

# Helper functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    print_info "Checking dependencies..."
    
    # Check for Python3
    if ! command -v python3 &> /dev/null; then
        print_error "python3 is not installed. Please install it first."
        exit 1
    fi
    
    # Check for pip3
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 is not installed. Please install it first."
        exit 1
    fi
    
    # Check for systemctl
    if ! command -v systemctl &> /dev/null; then
        print_error "systemctl is not available. This script requires systemd."
        exit 1
    fi
    
    # Check for stdbuf (from coreutils, usually pre-installed)
    if ! command -v stdbuf &> /dev/null; then
        print_warn "stdbuf is not installed. Line buffering may not work correctly."
    fi
    
    print_info "All required dependencies are installed."
}

install_python_dependencies() {
    print_info "Installing Python dependencies..."
    
    if [ ! -f "$REQUIREMENTS_FILE" ]; then
        print_error "Requirements file not found: $REQUIREMENTS_FILE"
        exit 1
    fi
    
    # Install for the service user
    if ! sudo -u "$SERVICE_USER" pip3 install --user -r "$REQUIREMENTS_FILE"; then
        print_error "Failed to install Python dependencies"
        exit 1
    fi
    
    print_info "Python dependencies installed successfully."
}

check_bme_logger() {
    if [ ! -f "$BME_LOGGER_PATH" ]; then
        print_warn "BME688 logger binary not found at: $BME_LOGGER_PATH"
        print_warn "Please compile the bme-logger first:"
        print_warn "  cd $SCRIPT_DIR/bme688-linux"
        print_warn "  make"
        print_warn "  cp out/bme-logger $SCRIPT_DIR/"
        return 1
    fi
    
    if [ ! -x "$BME_LOGGER_PATH" ]; then
        print_warn "BME688 logger is not executable. Making it executable..."
        chmod +x "$BME_LOGGER_PATH"
    fi
    
    return 0
}

create_logger_service() {
    print_info "Creating $LOGGER_SERVICE..."
    
    # Create the service file with proper escaping
    cat > "$SYSTEMD_DIR/$LOGGER_SERVICE" <<'EOF_HEADER'
[Unit]
Description=BME688 Sensor Data Logger and MQTT Publisher
After=network.target mosquitto.service
Wants=mosquitto.service

[Service]
Type=simple
EOF_HEADER
    
    cat >> "$SYSTEMD_DIR/$LOGGER_SERVICE" <<EOF
User=$SERVICE_USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=/bin/bash -c 'stdbuf -oL "$BME_LOGGER_PATH" | python3 "$PYTHON_PUBLISHER" --quiet --host "$MQTT_HOST" --port "$MQTT_PORT" --topic-prefix "$MQTT_TOPIC_PREFIX"'
EOF
    
    cat >> "$SYSTEMD_DIR/$LOGGER_SERVICE" <<'EOF_FOOTER'
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF_FOOTER
    
    print_info "Created $LOGGER_SERVICE"
}

create_collector_service() {
    print_info "Creating $COLLECTOR_SERVICE..."
    
    # Create the service file with proper escaping
    cat > "$SYSTEMD_DIR/$COLLECTOR_SERVICE" <<'EOF_HEADER'
[Unit]
Description=BME688 MQTT to SQLite Data Collector
After=network.target mosquitto.service bme688-logger.service
Wants=mosquitto.service

[Service]
Type=simple
EOF_HEADER
    
    cat >> "$SYSTEMD_DIR/$COLLECTOR_SERVICE" <<EOF
User=$SERVICE_USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=python3 "$PYTHON_COLLECTOR" --quiet --host "$MQTT_HOST" --port "$MQTT_PORT" --db "$DB_PATH" --topic "$MQTT_TOPIC_PREFIX/#"
EOF
    
    cat >> "$SYSTEMD_DIR/$COLLECTOR_SERVICE" <<'EOF_FOOTER'
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF_FOOTER
    
    print_info "Created $COLLECTOR_SERVICE"
}

install_services() {
    print_info "Installing BME688 data collection services..."
    
    check_dependencies
    install_python_dependencies
    
    # Check if bme-logger exists (warn but continue)
    if ! check_bme_logger; then
        print_warn "Continuing installation without bme-logger binary."
        print_warn "The logger service will fail until you compile and install the binary."
    fi
    
    # Create service files
    create_logger_service
    create_collector_service
    
    # Reload systemd
    print_info "Reloading systemd daemon..."
    systemctl daemon-reload
    
    print_info ""
    print_info "================================================"
    print_info "Services installed successfully!"
    print_info "================================================"
    print_info ""
    print_info "Available services:"
    print_info "  - $LOGGER_SERVICE (BME688 sensor reader + MQTT publisher)"
    print_info "  - $COLLECTOR_SERVICE (MQTT to SQLite collector)"
    print_info ""
    print_info "To enable and start the services:"
    print_info "  sudo systemctl enable $LOGGER_SERVICE"
    print_info "  sudo systemctl start $LOGGER_SERVICE"
    print_info "  sudo systemctl enable $COLLECTOR_SERVICE"
    print_info "  sudo systemctl start $COLLECTOR_SERVICE"
    print_info ""
    print_info "To check service status:"
    print_info "  sudo systemctl status $LOGGER_SERVICE"
    print_info "  sudo systemctl status $COLLECTOR_SERVICE"
    print_info ""
    print_info "To view logs:"
    print_info "  sudo journalctl -u $LOGGER_SERVICE -f"
    print_info "  sudo journalctl -u $COLLECTOR_SERVICE -f"
    print_info ""
    print_info "Database location: $DB_PATH"
    print_info "================================================"
}

uninstall_services() {
    print_info "Uninstalling BME688 data collection services..."
    
    # Stop services if running
    for service in "$LOGGER_SERVICE" "$COLLECTOR_SERVICE"; do
        if systemctl is-active --quiet "$service"; then
            print_info "Stopping $service..."
            systemctl stop "$service"
        fi
        
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            print_info "Disabling $service..."
            systemctl disable "$service"
        fi
        
        if [ -f "$SYSTEMD_DIR/$service" ]; then
            print_info "Removing $SYSTEMD_DIR/$service..."
            rm -f "$SYSTEMD_DIR/$service"
        fi
    done
    
    # Reload systemd
    print_info "Reloading systemd daemon..."
    systemctl daemon-reload
    
    print_info ""
    print_info "Services uninstalled successfully!"
    print_info "Note: Python dependencies and database files were not removed."
}

show_help() {
    cat <<EOF
BME688 Data Collection Service Installer

Usage: sudo bash install_services.sh [OPTIONS]

Options:
  --uninstall       Uninstall the services
  --help            Show this help message

Environment Variables (optional):
  SERVICE_USER      User to run services as (default: pi or current user)
  MQTT_HOST         MQTT broker host (default: 127.0.0.1)
  MQTT_PORT         MQTT broker port (default: 1883)
  MQTT_TOPIC_PREFIX MQTT topic prefix (default: measures/\$(hostname))
  DB_PATH           SQLite database path (default: $SCRIPT_DIR/measures.sqlite3)

Examples:
  # Install services with defaults
  sudo bash install_services.sh

  # Install with custom MQTT broker
  sudo MQTT_HOST=192.168.1.100 bash install_services.sh

  # Uninstall services
  sudo bash install_services.sh --uninstall

EOF
}

# Main script
main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi
    
    check_root
    
    if [ "$1" = "--uninstall" ]; then
        uninstall_services
    else
        install_services
    fi
}

main "$@"