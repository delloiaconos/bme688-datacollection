## Telegraf config (MQTT -> InfluxDB 1.8) 

This setup implements a lightweight ingestion pipeline that bridges MQTT telemetry to an InfluxDB 1.8 time-series database using Telegraf. 
Sensor nodes publish measurements as flat JSON payloads that include both the measured quantities (e.g., temperature, pressure, humidity, gas-related metrics) and a timestamp expressed as Unix epoch milliseconds. 
Messages are published to MQTT topics following the convention `measures/<host>/<id>`, where `<host>` identifies the originating device (or gateway) and `<id>` distinguishes the sensor/channel on that host.

Telegraf is configured with the `mqtt_consumer` input plugin to subscribe to the `measures/#` topic tree, decode each JSON payload, and map all numeric values to InfluxDB fields while preserving status as a string field. 
To support efficient querying and aggregation, Telegraf derives two tags directly from the topic path: host and id. 
Finally, Telegraf writes the resulting points to InfluxDB 1.8 via the native HTTP write API, using the embedded timestamp as the point time to maintain the original acquisition timeline even in the presence of network buffering or intermittent connectivity.

```toml
[[inputs.mqtt_consumer]]
  servers = ["tcp://127.0.0.1:1883"]
  topics  = ["measures/#"]
  qos = 0
  client_id = "telegraf-mqtt"

  # Don't keep the whole topic as a tag (we'll extract host/id instead)
  topic_tag = ""

  data_format = "json"
  json_time_key = "timestamp"
  json_time_format = "unix_ms"
  json_string_fields = ["status"]

  # Optional: name the measurement
  name_override = "measures"

  # Parse measures/<host>/<id> into tags
  [[inputs.mqtt_consumer.topic_parsing]]
    topic = "measures/+/+"
    tags  = "_/host/id"
```

That yields line protocol like:

- measurement: measures
- tags: host=<host>, id=<id>
- fields: temperature, pressure, humidity, gas_resistance, gas_index, meas_index, idac, status
- time: from timestamp [ms]

This topic parsing feature is documented by InfluxData and shown with the same [[inputs.mqtt_consumer.topic_parsing]] pattern.
