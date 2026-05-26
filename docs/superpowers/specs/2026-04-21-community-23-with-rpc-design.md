---
title: community-23 branch with Soroban RPC
date: 2026-04-21
status: approved
---

# community-23 with Soroban RPC

## Goal

Create `community-23` on top of `core-v23.0.1`, adding stellar-rpc alongside the
existing stellar-core + horizon services. Existing data volumes from earlier
community releases must keep working, and an opt-in migration must register the
new RPC service into their already-initialized volume.

## Base

- **Branch base:** `core-v23.0.1` — already builds stellar-core v23.0.1 +
  horizon v23.0.0 on Ubuntu 20.04 + PostgreSQL 12. Keep it unchanged.
- **Upgrade to Ubuntu 24.04 + PG14:** deferred to a follow-up branch.

## Versions

| Component    | Version       | Notes                            |
|--------------|---------------|----------------------------------|
| stellar-core | v23.0.1       | inherited from base              |
| horizon      | v23.0.0       | inherited from base              |
| stellar-rpc  | v23.0.4       | latest release in the v23 line   |

Tag: `community-v1.0-p23.0.1` (reset to v1.0 on core major bump).

## Build

- **New `Dockerfile.rpc`** — builder based on `golang:1.23` + rustup (matches
  quickstart's RPC stage, trimmed to what stellar-rpc needs). Clones
  `stellar/stellar-rpc` at `$REF`, runs `make build-stellar-rpc`, exports
  `/stellar-rpc` binary.
- **`Makefile`** — add `RPC_REF?=v23.0.4`, `build-deps-rpc` target, feed
  `STELLAR_RPC_IMAGE_REF=stellar-rpc:$(RPC_REF)` into final `build`.
- **`Dockerfile`** — accept `STELLAR_RPC_IMAGE_REF`, `COPY --from=rpc
  /stellar-rpc /usr/bin/stellar-rpc`, add RPC port exposes (8003 JSON-RPC,
  11826 captive-core HTTP, 6061 admin), `ADD common/stellar-rpc` and the
  per-network `*/stellar-rpc` trees.

## Runtime

- **`start` script** — add `STELLAR_RPC_HOME=/opt/stellar/stellar-rpc`, new
  `init_stellar_rpc` function that substitutes `__NETWORK__`, `__ARCHIVE__`,
  `__STELLAR_RPC_ADMIN_ENDPOINT__`, `__DATABASE__` placeholders (captive-core
  uses sqlite, not PG). Call after `init_horizon`. Copy defaults for RPC
  added to `copy_defaults`.
- **`ENABLE_RPC_ADMIN_ENDPOINT`** env var, off by default. When true, admin
  binds to `0.0.0.0:6061`; when false, admin is disabled (empty endpoint).

## Supervisor

- Add `[program:stellar-rpc]` to `common/supervisor/etc/supervisord.conf` with
  `autostart=false` and `user=stellar`. Matches horizon's opt-in pattern.
  Default-started processes remain: `postgresql`, `stellar-core`.

## Configs

- **`common/stellar-rpc/etc/stellar-rpc.cfg`** — placeholders for
  `__NETWORK__`, `__ARCHIVE__`, `__STELLAR_RPC_ADMIN_ENDPOINT__`. Captive-core
  HTTP port 11826 (disjoint from core 11626 and horizon 11726).
- **`common/stellar-rpc/etc/stellar-captive-core.cfg`** — placeholder for
  `__NETWORK__`, `__DATABASE__`, disjoint PEER_PORT=11825, references the Pi
  validators via per-network override.
- **`{mainnet,testnet,testnet2}/stellar-rpc/etc/stellar-captive-core.cfg`** —
  appends `[[VALIDATORS]]` / `[[HOME_DOMAINS]]` matching the network's
  `core/etc/stellar-core.cfg`. These are merged over the common file via the
  same rsync layering already used for core/horizon.
- **`common/stellar-rpc/bin/start`** — tiny wrapper that waits for postgres +
  core, then `exec stellar-rpc --config-path .../stellar-rpc.cfg`.

## Migration 004 (old volumes)

`migrations/004_add_rpc_service.sh` — idempotent, runs every start via the
existing runner, marked complete after success:

1. If `/opt/stellar/stellar-rpc/etc/stellar-rpc.cfg` exists → skip.
2. `rsync -a /opt/stellar-default/common/stellar-rpc/ /opt/stellar/stellar-rpc/`
3. `rsync -a /opt/stellar-default/$NETWORK/stellar-rpc/ /opt/stellar/stellar-rpc/`
4. Substitute `__NETWORK__`, `__ARCHIVE__`, `__STELLAR_RPC_ADMIN_ENDPOINT__`,
   `__DATABASE__` in the copied files (same logic as `init_stellar_rpc`).
5. Append `[program:stellar-rpc]` block to
   `/opt/stellar/supervisor/etc/supervisord.conf` only if not already present
   (grep guard).
6. `chown -R stellar:stellar /opt/stellar/stellar-rpc`.
7. Touch `.quickstart-initialized` under the RPC home so the start script's
   init skips on later restarts.

Existing users get RPC available (but `autostart=false`, opt-in via
`supervisorctl start stellar-rpc`). Fresh installs use the normal init path.

## Ports

| Port  | Service         | Notes                                   |
|-------|-----------------|-----------------------------------------|
| 5432  | postgresql      | unchanged                               |
| 8000  | horizon         | unchanged                               |
| 6060  | horizon admin   | unchanged                               |
| 31402 | stellar-core    | unchanged                               |
| 8003  | stellar-rpc     | JSON-RPC endpoint                       |
| 6061  | stellar-rpc     | admin (opt-in via env)                  |
| 11826 | stellar-rpc     | captive-core HTTP (internal)            |

## Out of scope

- Ubuntu 24.04 / PG14 upgrade (next branch).
- Friendbot, lab, galexie (not needed for Pi community nodes).
- Auto-starting RPC at boot (operators opt in via supervisorctl).

## README

Rewrite to list stellar-rpc in versions/ports/autostart tables, document
`ENABLE_RPC_ADMIN_ENDPOINT`, and bump tag references to
`community-v1.0-p23.0.1`.
