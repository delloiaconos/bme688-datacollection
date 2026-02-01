## Mosquitto

### Verify it's working

LISTEN: On a terminal:
```bash
mosquitto_sub -h 127.0.0.1 -t "test/topic"
```

PUBLISH: On a different terminal on the same host:
```bash
mosquitto_pub -h 127.0.0.1 -t "test/topic" -m "Hello Localhost"
```


## Simple Logger


```bash
stdbuf -oL bme-logger | mosquitto_pub -h 127.0.0.1 -t "test/test" -l
```

Details:
- `stdbuf -oL`: Forces the command's Output to be Line buffered (flush immediately on every `\n`).
- `-l`: Tells Mosquitto to read line-by-line and publish instantly.