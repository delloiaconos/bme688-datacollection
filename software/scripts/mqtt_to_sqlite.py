#!/usr/bin/env python3
import argparse
import json
import signal
import sqlite3
import threading
import time
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Tuple

import paho.mqtt.client as mqtt

_db_lock = threading.Lock()


SCHEMA_TEMPLATE = """
CREATE TABLE IF NOT EXISTS {table} (
    measid           INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Message reception time (UTC)
    received_utc     TEXT NOT NULL,

    -- Extracted from MQTT topic: measurements/<host>/<id>
    host            TEXT NOT NULL,
    sensor_id       TEXT NOT NULL,

    -- Payload timestamp (from JSON), if present
    timestamp_ms     INTEGER,

    -- Measurements (from JSON)
    temperature      REAL,
    pressure         REAL,
    humidity         REAL,
    gas_resistance   REAL,
    gas_index        INTEGER,
    meas_index       INTEGER,
    idac             INTEGER,
    status           TEXT
);

CREATE INDEX IF NOT EXISTS idx_{table}_host_sensor_time
ON {table}(host, sensor_id, received_utc);

CREATE INDEX IF NOT EXISTS idx_{table}_timestamp_ms
ON {table}(timestamp_ms);
"""


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Subscribe to MQTT and store BME-like JSON payloads into SQLite. Topic: measurements/<host>/<id>."
    )

    p.add_argument("--host", default="127.0.0.1", help="MQTT broker hostname/IP (default: 127.0.0.1)")
    p.add_argument("--port", type=int, default=1883, help="MQTT broker port (default: 1883)")
    p.add_argument("--topic", default="measures/#", help="MQTT topic filter to subscribe to (e.g. measurements/#)")
    p.add_argument("--qos", type=int, choices=[0, 1, 2], default=1, help="Subscription QoS (default: 1)")

    p.add_argument("--username", default=None, help="MQTT username (optional)")
    p.add_argument("--password", default=None, help="MQTT password (optional)")
    p.add_argument("--tls", action="store_true", help="Enable TLS with default settings")
    p.add_argument("--client-id", default="mqtt-to-sqlite", help="MQTT client id (default: mqtt-to-sqlite)")

    p.add_argument("--db", default="measures.sqlite3", help="SQLite DB path (default: measures.sqlite3)")
    p.add_argument("--table", default="measures", help="SQLite table name (default: measures)")

    p.add_argument("--topic-prefix", default="measures",
                   help="Expected topic prefix (default: measures). Full topic must be prefix/host/id")
    p.add_argument("--drop-bad-topic", action="store_true",
                   help="Drop messages whose topic doesn't match prefix/host/id (default: store with error -> dropped anyway)")
    p.add_argument("--require-json", action="store_true",
                   help="Drop messages that are not valid JSON (recommended)")
    p.add_argument("--quiet", action="store_true", help="Reduce console output")
    return p


def db_init(db_path: str, table: str) -> None:
    schema = SCHEMA_TEMPLATE.format(table=table)
    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.executescript(schema)
        conn.commit()


def _to_int(v: Any) -> Optional[int]:
    if v is None:
        return None
    try:
        return int(v)
    except Exception:
        return None


def _to_float(v: Any) -> Optional[float]:
    if v is None:
        return None
    try:
        return float(v)
    except Exception:
        return None


def parse_topic(topic: str, expected_prefix: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """
    Returns (host, sensor_id, error). Expected format: <expected_prefix>/<host>/<id>
    """
    parts = topic.split("/")
    if len(parts) != 3:
        return None, None, f"topic parts != 3 (got {len(parts)})"
    prefix, host, sensor_id = parts
    if prefix != expected_prefix:
        return None, None, f"unexpected prefix '{prefix}' (expected '{expected_prefix}')"
    if not host or not sensor_id:
        return None, None, "empty host or id"
    return host, sensor_id, None


def parse_payload(payload_bytes: bytes) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
    try:
        obj = json.loads(payload_bytes.decode("utf-8"))
        if not isinstance(obj, dict):
            return None, "JSON is not an object"
        return obj, None
    except Exception as e:
        return None, str(e)


def extract_fields(obj: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "timestamp_ms": _to_int(obj.get("timestamp")),
        "temperature": _to_float(obj.get("temperature")),
        "pressure": _to_float(obj.get("pressure")),
        "humidity": _to_float(obj.get("humidity")),
        "gas_resistance": _to_float(obj.get("gas_resistance")),
        "gas_index": _to_int(obj.get("gas_index")),
        "meas_index": _to_int(obj.get("meas_index")),
        "idac": _to_int(obj.get("idac")),
        "status": obj.get("status"),
    }


def db_insert(db_path: str, table: str, row: Dict[str, Any]) -> None:
    sql = f"""
    INSERT INTO {table}
    (received_utc, host, sensor_id,
     timestamp_ms,
     temperature, pressure, humidity, gas_resistance, gas_index, meas_index, idac, status)
    VALUES (?, ?, ?,
            ?,
            ?, ?, ?, ?, ?, ?, ?, ?)
    """
    with _db_lock:
        with sqlite3.connect(db_path) as conn:
            conn.execute("PRAGMA journal_mode=WAL;")
            conn.execute(
                sql,
                (
                    row["received_utc"],
                    row["host"],
                    row["sensor_id"],
                    row.get("timestamp_ms"),
                    row.get("temperature"),
                    row.get("pressure"),
                    row.get("humidity"),
                    row.get("gas_resistance"),
                    row.get("gas_index"),
                    row.get("meas_index"),
                    row.get("idac"),
                    row.get("status"),
                ),
            )
            conn.commit()


def main() -> None:
    args = build_arg_parser().parse_args()
    db_init(args.db, args.table)

    def log(msg: str) -> None:
        if not args.quiet:
            print(msg)

    client = mqtt.Client(client_id=args.client_id, protocol=mqtt.MQTTv311)

    if args.username is not None:
        client.username_pw_set(args.username, args.password or "")

    if args.tls:
        client.tls_set()

    stop_event = threading.Event()

    def handle_sig(*_):
        stop_event.set()

    signal.signal(signal.SIGINT, handle_sig)
    signal.signal(signal.SIGTERM, handle_sig)

    def on_connect(_client, _userdata, _flags, rc, properties=None):
        if rc == 0:
            log(f"[MQTT] Connected to {args.host}:{args.port} | subscribe '{args.topic}' qos={args.qos}")
            _client.subscribe(args.topic, qos=args.qos)
        else:
            log(f"[MQTT] Connect failed rc={rc}")

    def on_message(_client, _userdata, msg):
        received_utc = datetime.now(timezone.utc).isoformat()

        host, sensor_id, topic_err = parse_topic(msg.topic, args.topic_prefix)
        if topic_err:
            if args.drop_bad_topic:
                log(f"[DROP] bad topic '{msg.topic}': {topic_err}")
                return
            # If you prefer storing unknown topics, we could add nullable columns.
            # But you asked to remove topic column, so we must drop.
            log(f"[DROP] bad topic '{msg.topic}': {topic_err}")
            return

        obj, json_err = parse_payload(msg.payload)
        if obj is None:
            if args.require_json:
                log(f"[DROP] non-JSON payload topic='{msg.topic}' err={json_err}")
                return
            # Without payload column, we cannot store raw bytes; so drop.
            log(f"[DROP] non-JSON payload topic='{msg.topic}' err={json_err}")
            return

        row: Dict[str, Any] = {
            "received_utc": received_utc,
            "host": host,
            "sensor_id": sensor_id,
            **extract_fields(obj),
        }

        try:
            db_insert(args.db, args.table, row)
            log(f"[DB] saved host='{host}' id='{sensor_id}' ts_ms={row.get('timestamp_ms')}")
        except Exception as e:
            log(f"[DB] insert failed: {e}")

    client.on_connect = on_connect
    client.on_message = on_message
    client.reconnect_delay_set(min_delay=1, max_delay=30)

    log(f"[START] DB='{args.db}' TABLE='{args.table}' MQTT='{args.host}:{args.port}' SUB='{args.topic}'")
    client.connect(args.host, args.port, keepalive=60)
    client.loop_start()

    try:
        while not stop_event.is_set():
            time.sleep(0.2)
    finally:
        log("[STOP] shutting down...")
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    #main()
    raise SystemExit(main())

