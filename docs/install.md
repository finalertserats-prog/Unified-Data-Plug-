# Installation

## Fast install

```bash
bash install.sh
```

The installer checks Docker, creates `.env`, starts the stack, bootstraps demo data, and runs smoke tests.

## Manual install

```bash
cp .env.example .env
./udp doctor
./udp start
./udp bootstrap
./udp smoke-test
```

## Optional governance plane

```bash
./udp ranger up
# Ranger admin: http://localhost:6080
# First run builds Ranger from upstream Apache source (~10 min).
```

## Access points

| Service | URL / Port |
|---|---|
| MinIO API | http://localhost:9000 |
| MinIO Console | http://localhost:9001 |
| Hive Metastore (Thrift) | thrift://localhost:9083 |
| Spark Notebook | http://localhost:8888 |
| StarRocks FE UI | http://localhost:8030 |
| StarRocks MySQL | localhost:9030 |
| Ranger Admin (optional) | http://localhost:6080 |
