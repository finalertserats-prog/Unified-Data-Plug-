# Apache Ranger (v0.3 preview)

UDP ships Apache Ranger as an **opt-in** compose profile. It provides the **policy-admin plane only** — the web UI where roles, resources, and access policies are managed.

## What works in v0.3
- Ranger admin UI at http://localhost:6080
- Postgres-backed policy store
- UNIX-style local auth (`admin` / `${RANGER_ADMIN_PASSWORD}`)
- Policy CRUD for any registered service definition

## What doesn't work yet (v0.4)
- StarRocks enforcement plugin — no first-class plugin exists upstream
- Audit-to-Solr — disabled in v0.3 to keep the footprint small
- HMS plugin auto-registration — must be wired manually

## Why Ranger is opt-in

Ranger admin is built from upstream source on first run (`./udp ranger up`), taking ~10 minutes. The core lakehouse (`./udp start`) does not depend on Ranger.

## Commands

```bash
./udp ranger up      # build + start
./udp ranger logs    # tail admin logs
./udp ranger down    # stop (data preserved in volume)
```

## Image source

The `Dockerfile` clones `apache/ranger` at tag `release-ranger-2.4.0` and runs the upstream Maven build for `security-admin`. There is no official Apache image on Docker Hub at the time of writing — this is the standard upstream-source approach.

To pin a different version, override the build arg:

```yaml
ranger-admin:
  build:
    context: ./services/ranger
    args:
      RANGER_VERSION: release-ranger-2.5.0
```
