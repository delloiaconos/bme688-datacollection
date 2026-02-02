 #!/usr/bin/env bash
set -euo pipefail

BME_BASE="/opt/bme"

exec stdbuf -oL $BME_BASE/bme-grabber | $BME_BASE/env/bin/python $BME_BASE/stream_publisher.py --quiet --topic-prefix "measures/$(hostname)"
