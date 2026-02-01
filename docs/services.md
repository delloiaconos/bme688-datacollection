## Linux Systemd Services

### SystemCtl

Reload systemd unit files (apply service file changes) fter editing/copying .service files
```bash
sudo systemctl daemon-reload
```

Additional examples:
```bash
# Start a service now
sudo systemctl start bme-collector.service

# Stop a service now
sudo systemctl stop bme-collector.service

# Restart a service (most common after changes)
sudo systemctl restart bme-collector.service

# Reload a service (only works if the service supports reload)
sudo systemctl reload bme-collector.service

# Enable service at boot
sudo systemctl enable bme-collector.service

# Disable service at boot
sudo systemctl disable bme-collector.service

# Enable and start immediately
sudo systemctl enable --now bme-collector.service

# Check status (with recent logs)
systemctl status bme-collector.service

# Show if active (exit code indicates state)
systemctl is-active bme-collector.service

# Show if enabled at boot
systemctl is-enabled bme-collector.service

# View unit file contents and drop-ins
systemctl cat bme-collector.service

# List all units of type service
systemctl list-units --type=service

# List installed unit files (enabled/disabled)
systemctl list-unit-files --type=service

# Show detailed properties (good for debugging)
systemctl show bme-collector.service

# Edit with a drop-in override (recommended instead of editing vendor files)
sudo systemctl edit bme-collector.service

# Reset overrides (remove drop-in changes)
sudo systemctl revert bme-collector.service

# If a service is stuck in "failed", clear the failed state
sudo systemctl reset-failed bme-collector.service
```

### JournalCtl

Use  `journalctl` like this:

```bash
sudo journalctl -u bme-collector.service
```


Follow live logs (like tail -f):
```bash
sudo journalctl -u bme-collector.service -f
```

Only logs from the current boot
```bash
sudo journalctl -u bme-collector.service -b
```

Last 200 lines (current boot)
```bash
sudo journalctl -u bme-collector.service -b -n 200
```

Show full lines (no truncation)
```bash
sudo journalctl -u bme-collector.service -b -n 200 --no-pager -l
```

Since a time
```bash
sudo journalctl -u bme-collector.service --since "2026-02-01 00:00:00"
sudo journalctl -u bme-collector.service --since "10 minutes ago"
```
