## Troubleshooting

### Sensor not found in `i2cdetect`
- Confirm I²C is enabled in `raspi-config`
- Verify the correct I²C bus (`1` is most common)
- Check cabling/PCB orientation and power
- Ensure the correct address (`0x76` vs `0x77`)

### Permission errors on `/dev/i2c-*`
Run with `sudo`, or add your user to the `i2c` group (if available on your distro):
```bash
sudo usermod -aG i2c $USER
# Log out and back in
```