#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
import time
from typing import Any, Dict, Optional

import paho.mqtt.client as mqtt


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Read JSON lines from stdin and publish msg['measures'] to MQTT topic <prefix>/<idx>, adding timestamp."
    )
    p.add_argument("--host", default="127.0.0.1", help="MQTT broker host/IP (default: 127.0.0.1)")
    p.add_argument("--port", type=int, default=1883, help="MQTT broker port (default: 1883)")
    p.add_argument("--username", default=None, help="MQTT username (optional)")
    p.add_argument("--password", default=None, help="MQTT password (optional)")
    p.add_argument("--client-id", default=f"stdin-pub-{int(time.time())}", help="MQTT client id")
    p.add_argument("--qos", type=int, default=0, choices=[0, 1, 2], help="MQTT QoS (default: 0)")
    p.add_argument("--retain", action="store_true", help="Publish with retain flag (default: off)")
    p.add_argument(
        "--topic-prefix",
        default="measures",
        help="Topic prefix (default: measures). Final topic: <prefix>/<idx>",
    )
    p.add_argument(
        "--keepalive",
        type=int,
        default=60,
        help="MQTT keepalive seconds (default: 60)",
    )
    p.add_argument(
        "--reconnect-delay",
        type=float,
        default=2.0,
        help="Seconds to wait between reconnect attempts (default: 2.0)",
    )
    p.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress per-message success logs",
    )
    return p.parse_args()


def build_topic(prefix: str, idx_value: Any) -> str:
    prefix = prefix.strip()
    if prefix == "":
        # topic is just idx (no leading slash)
        return str(idx_value)
    return f"{prefix.rstrip('/')}/{str(idx_value)}"


def extract_payload(line_obj: Dict[str, Any]) -> tuple[str, Dict[str, Any]]:
    if "idx" not in line_obj:
        raise ValueError("Missing required field: idx")
    if "measures" not in line_obj:
        raise ValueError("Missing required field: measures")
    if not isinstance(line_obj["measures"], dict):
        raise ValueError("'measures' must be a JSON object")

    measures = dict(line_obj["measures"])  # copy

    # REQUIRED: add timestamp field to the measurement
    ts = line_obj.get("timestamp")
    if ts is None:
        ts = int(time.time() * 1000)
    measures["timestamp"] = ts

    topic = build_topic(args.topic_prefix, line_obj["idx"])
    return topic, measures


def ensure_connected(client: mqtt.Client, host: str, port: int, keepalive: int, delay: float) -> None:
    # paho-mqtt will handle reconnects if loop is running, but we also try initially.
    while True:
        try:
            client.connect(host, port, keepalive=keepalive)
            return
        except Exception as e:
            print(f"MQTT connect failed: {e}. Retrying in {delay}s...", file=sys.stderr)
            time.sleep(delay)


def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print("MQTT connected", file=sys.stderr)
    else:
        print(f"MQTT connection error rc={rc}", file=sys.stderr)


def on_disconnect(client, userdata, rc, properties=None):
    # rc != 0 means unexpected disconnect
    if rc != 0:
        print(f"MQTT disconnected unexpectedly (rc={rc})", file=sys.stderr)


args = parse_args()


def main() -> int:
    client = mqtt.Client(client_id=args.client_id, clean_session=True)

    client.on_connect = on_connect
    client.on_disconnect = on_disconnect

    if args.username is not None:
        client.username_pw_set(args.username, args.password)

    # Auto-reconnect behavior
    # (reconnect_delay_set is available in paho-mqtt)
    try:
        client.reconnect_delay_set(min_delay=1, max_delay=30)
    except Exception:
        pass

    ensure_connected(client, args.host, args.port, args.keepalive, args.reconnect_delay)
    client.loop_start()

    # Read stdin continuously, line by line
    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue  # ignore empty lines

        try:
            obj = json.loads(line)
            if not isinstance(obj, dict):
                raise ValueError("Top-level JSON must be an object")
            topic, measures = extract_payload(obj)

            payload_str = json.dumps(measures, separators=(",", ":"), ensure_ascii=False)
            info = client.publish(topic, payload_str, qos=args.qos, retain=args.retain)

            # wait for completion (important for QoS 1/2)
            info.wait_for_publish(timeout=10)
            if info.rc != mqtt.MQTT_ERR_SUCCESS:
                raise RuntimeError(f"publish failed rc={info.rc}")

            if not args.quiet:
                print(f"OK topic={topic} payload={payload_str}", file=sys.stderr)

        except Exception as e:
            # Keep running even if a line is malformed or publish fails
            print(f"ERR line={line!r} error={e}", file=sys.stderr)
            continue

    # EOF on stdin
    client.loop_stop()
    client.disconnect()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
