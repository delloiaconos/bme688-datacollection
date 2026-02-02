## Measurement

### Read BME688

The `bme-logger` needs to be compiled before exection.

```bash
./bme-logger 
```

### BME688 -> MQTT Broker

`stream_publisher.py` is a small command-line tool that streams newline-delimited JSON (NDJSON) from standard input and publishes sensor measurements to an MQTT broker.

For each input line, it:

- parses the line as JSON
- reads idx and measures
- publishes only the measures object to MQTT
- adds a timestamp field into the published measures payload (uses the input timestamp if present, otherwise current time in ms)
- publishes to topic: <topic-prefix>/<idx> (default prefix: measures, so e.g. measures/7)

Invalid lines (bad JSON / missing fields / publish errors) are logged to stderr and the program continues processing the next line.

```bash
stdbuf -oL ./bme-logger | python3 stream_publisher.py --quiet --topic-prefix "measures/$(hostname)"
```

This pipeline runs your logger and sends each line it prints to the MQTT sender, with low latency and host-specific topics.

## Testing

once the services have been started, in order to check if the stream publisher is working:

```bash
mosquitto_sub -h 127.0.0.1 -t "measures/#"
```


## Data Collection

### MQTT -> SQLite3

```bash
python3 mqtt_to_sqlite.py --quiet
```

## Data Visualization

### SQLite3 Examples

Get last 10 measures:
```bash
sqlite3 measures.sqlite3 "SELECT * FROM measures ORDER BY measid DESC LIMIT 10;"
```

### Export to CSV

Export a whole table to CSV:
```bash
sqlite3 -header -csv measures.sqlite3 "SELECT * FROM measures;" > measures.csv
```

Export only some columns / filtered rows:
```bash
sqlite3 -header -csv measures.sqlite3 \
  "SELECT timestamp_utc, host, sensor_id, temperature, humidity, pressure
   FROM measures
   WHERE host='raspi1'
   ORDER BY timestamp_ms;" > filtered.csv
```

### Interactive Mode

Export with the interactive example (this is not suggested for long outputs):
```bash
sqlite3 measures.sqlite3
sqlite> .headers on
sqlite> .mode csv
sqlite> .output measures.csv
sqlite> SELECT * FROM measures;
sqlite> .output stdout
sqlite> .quit
```