 #!/usr/bin/env bash
set -euo pipefail

BME_BASE="/opt/bme"

mkdir -p "$BME_BASE/data"
BME_DB="$BME_BASE/data/db-$(date +%Y%m%d%H%M%S).sqlite3"

exec "$BME_BASE/env/bin/python" "$BME_BASE/mqtt_to_sqlite.py" --quiet --db "$BME_DB"