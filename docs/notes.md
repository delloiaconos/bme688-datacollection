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
stdbuf -oL ./bme-logger | mosquitto_pub -h 127.0.0.1 -t "test/topic" -l
```

Details:
- `stdbuf -oL`: Forces the command's Output to be Line buffered (flush immediately on every `\n`).
- `-l`: Tells Mosquitto to read line-by-line and publish instantly.

## SQLite3

When working with sqlite you can find additional files:
- `yourdb.sqlite3` The main database file (the actual tables/indexes).
- `yourdb.sqlite3-wal` The write-ahead log. New/updated pages are appended here first instead of being written directly into the main DB file.
- `yourdb.sqlite3-shm` The shared-memory index used by SQLite to coordinate readers/writers in WAL mode (locking + bookkeeping so multiple connections can safely access the DB).


In WAL (Write-Ahead Logging) mode, infact, SQLite splits work across multiple files for speed and concurrency.
They often remain while the DB is in use, but they can remain also afther a shutdown.
They may be removed after a checkpoint (when WAL content is merged back into the main DB) and when all connections are closed.

If you want to force merging and reduce/clean them, From the sqlite3 shell:

```sql
PRAGMA wal_checkpoint(FULL);
```

Or if you don’t want WAL mode at all (slower concurrency, but single file more often):
```sql
PRAGMA journal_mode=DELETE;
```

