# UDP Security Model

This document describes the threat model, current posture, and the deferred
hardening items for Unified Data Plug. Read this before deploying outside a
trusted local network.

## What UDP protects today (post Phase 0 + 1)

- **No hardcoded credentials** in any committed file. The two configs that
  previously embedded `admin/udp_admin_12345` (Spark defaults + StarRocks
  external-catalog DDL) are now `*.template` files rendered from `.env` at
  install/bootstrap time. Rendered outputs are gitignored.
- **All credentials generated at install** via `openssl rand -hex 16` (or
  `/dev/urandom` fallback). `.env` is written with mode `0600` and the
  generated values are **never echoed to the terminal** — read them with
  `cat .env`.
- **StarRocks `root` requires a credential** — `scripts/set-starrocks-password.sh`
  applies it after FE start; `bootstrap.sh` and `smoke-test.sh` pass `-p` to all
  `mysql` invocations; the compose healthcheck adapts via
  `${STARROCKS_ROOT_PASSWORD:+-p$$STARROCKS_ROOT_PASSWORD}`.
- **All host ports bound to `127.0.0.1`** — services are reachable only from
  the install host, not from the LAN. Connecting from another machine requires
  an explicit SSH tunnel (`ssh -L 9001:127.0.0.1:9001 udp-host`).
- **StarRocks RBAC from policy YAML** — `scripts/generate-starrocks-users.py`
  reads `governance/policies/*.yaml` and emits a templated SQL that creates
  least-privilege users (e.g. `analyst`, `viewer`) with generated credentials.
  `bootstrap.sh` applies it after the analytics views are created.
- **`./udp clean` is gated** — typing `wipe` (or passing `--yes` for scripts)
  is required before volumes are removed.
- **Image digest pinning** — every image in `docker-compose.yml` is pinned to a
  `@sha256:` digest. The `pinned-images` CI job rejects any new image line
  without one.
- **CI gates**: gitleaks, shellcheck, trivy (config + image CVE), compose
  config lint, and no-rendered-templates guard run on every push and PR.

## What UDP does NOT protect today

The following risks are real and accepted for Phase 0/1. They are tracked in
the roadmap for later phases:

| Risk | Why deferred | Mitigation today | Target phase |
|---|---|---|---|
| **No TLS** on MinIO, Iceberg REST, StarRocks MySQL/FE, Spark UI | Adds reverse-proxy/cert-management complexity that fits better with ingress/HA | Loopback-only port binding makes interception require host access, which is already game over | Phase 6 (HA + ingress) |
| **No authentication on Iceberg REST** | Upstream `tabulario/iceberg-rest` image has no built-in auth | Loopback-only binding; no LAN exposure | Phase 6 (swap to Polaris/Lakekeeper) |
| **MinIO is single-node** (no erasure coding) | Single-host install | Use real S3/GCS/Azure Blob in production deployments; MinIO retained for local/dev | Phase 2 (distributed mode or document S3) |
| **Iceberg REST catalog uses default backing** (in-memory/SQLite) | Default tabulario image | Restart = metadata loss for now | Phase 2 (Postgres-backed) |
| **Spark Jupyter notebook has no auth** | Tabulario image default | Loopback-only binding; do not enable token-less Jupyter on a shared host | Phase 6 |
| **No mTLS between services on the Docker network** | Internal network is treated as trusted | Single-host install means the Docker bridge is host-local | Phase 6 |
| **No audit log of catalog/data access** | Observability work not yet wired | StarRocks fe.audit.log is on by default, but not collected | Phase 3 (observability) |
| **Row filters & column masks in policy YAML are advisory comments** | StarRocks 3.3 row-policy syntax varies; needs engine integration | Use coarse-grained `GRANT SELECT` per role for now | Phase 7 (governance & RBAC) |
| **Container runs as default user** (not unprivileged UID) | Upstream image defaults | None today | Phase 6 |
| **No resource limits** on services | Defaults left untouched | Run on a dedicated VM | Phase 2 |

## Threat model assumptions

- **Trust boundary**: the install host. Anyone with shell or root on the host
  has full access. UDP does not defend against host compromise.
- **Network exposure**: zero by default. All published ports are bound to the
  loopback interface. Operators choose how to expose UDP externally (SSH
  tunnels, VPN, ingress with TLS — see Phase 6).
- **Data sensitivity**: assume the data lake contains regulated data. Treat
  MinIO buckets and Iceberg tables as confidential.

## Pre-production checklist

Before promoting UDP from "running locally" to "serving real traffic":

- [ ] Replace MinIO with managed object storage (AWS S3, GCS, Azure Blob, or
      MinIO in distributed mode across ≥4 nodes)
- [ ] Replace tabulario/iceberg-rest with a Postgres-backed catalog (Polaris,
      Lakekeeper, or equivalent) — Phase 2
- [ ] Front MinIO API, MinIO Console, Iceberg REST, Spark UI, and StarRocks FE
      UI behind a TLS-terminating ingress (Traefik, NGINX, ALB, etc.) — Phase 6
- [ ] Move secrets out of `.env` into a real secret manager (Vault, AWS Secrets
      Manager, GCP Secret Manager, sealed-secrets, SOPS) — Phase 6
- [ ] Enable MinIO server-side encryption (SSE-KMS) — Phase 2
- [ ] Rotate the StarRocks `root` credential out of operational use; expose only
      the policy-generated roles
- [ ] Stand up backups (Velero, restic, or cloud-native snapshots) and prove
      restore — Phase 2
- [ ] Wire Prometheus/Grafana/Loki and ship logs to a central store — Phase 3
- [ ] Add resource limits (`deploy.resources.limits.{cpus,memory}`) to every
      service — Phase 2
- [ ] Verify trivy image scans show no unaddressed CRITICAL CVEs (currently
      report-only in CI)
- [ ] Run a tabletop exercise: simulated credential leak, lost MinIO volume,
      lost StarRocks FE metadata — confirm runbooks exist for each

## Reporting a vulnerability

Open a private security advisory on the repository's GitHub Security tab.
Do not file public issues for unpatched vulnerabilities.
