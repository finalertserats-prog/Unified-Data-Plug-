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
