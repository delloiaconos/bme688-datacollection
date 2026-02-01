## Measuremnts Collection

`stream_publisher.py` is a small command-line tool that streams newline-delimited JSON (NDJSON) from standard input and publishes sensor measurements to an MQTT broker.

For each input line, it:

- parses the line as JSON
- reads idx and measures
- publishes only the measures object to MQTT
- adds a timestamp field into the published measures payload (uses the input timestamp if present, otherwise current time in ms)
- publishes to topic: <topic-prefix>/<idx> (default prefix: measures, so e.g. measures/7)

Invalid lines (bad JSON / missing fields / publish errors) are logged to stderr and the program continues processing the next line.

### How to run

```bash
stdbuf -oL ./bme-logger | python3 stream_publisher.py --quiet --topic-prefix "measures/$(hostname)"
```

This pipeline runs your logger and sends each line it prints to the MQTT sender, with low latency and host-specific topics.