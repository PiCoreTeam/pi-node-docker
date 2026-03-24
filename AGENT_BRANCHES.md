# Pi Node Docker — Branch Maintenance Guide

## Branches

| Branch | Image Tag | Purpose |
|--------|-----------|---------|
| `community` | `community-v1.1-p21.2` | Community watcher nodes |
| `mainnet_relay` | `mainnet_relay-v1.0-p21.2` | Mainnet relay nodes with history publishing |
| `organization-mainnet_21.2` | `organization-mainnet-v1.0-p21.2-RC1` | Organization full nodes |

## Shared Stack

All three branches use the same versions:

- Stellar Core: v21.2.0 (built from source via `Dockerfile.core`)
- Horizon: v2.32.0 (built from source via `Dockerfile.horizon`)
- PostgreSQL: 12
- Base OS: Ubuntu 20.04 (Focal)

## Branch Differences

### community

- **Network**: mainnet, testnet, testnet2
- **Entrypoint flags**: `--mainnet`, `--testnet`, `--testnet2`
- **Stellar Core**: autostart=true
- **Horizon**: autostart=false (on-demand via `supervisorctl start horizon`)
- **History server**: none
- **Auto-migrations**: always run, no flag to disable
- **Previous images**: `community-v1.0-p19.9`, `community-v1.0-p20.2`
- **Supervisor programs**: postgresql, stellar-core, horizon

### mainnet_relay

- **Network**: mainnet only
- **Entrypoint flags**: `--mainnetrelay`
- **Stellar Core**: autostart=true
- **Horizon**: autostart=false (on-demand via `supervisorctl start horizon`)
- **History server**: webfsd on port 1570 (autostart=true in supervisor), serves `/opt/stellar/history/local/`
- **Auto-migrations**: always run, no flag to disable
- **Previous images**: `mainnet_relay-v1.0-p19.9`, `mainnet_relay-v1.0-p20.2`, `mainnet_relay-v1.0-p20.4`
- **Supervisor programs**: postgresql, stellar-core, webfsd, horizon
- **Core config**: publishes history via `[HISTORY.local]` put/get/mkdir

### organization-mainnet_21.2

- **Network**: mainnet only (internally called `pubnet`)
- **Entrypoint flags**: `--mainnet`, `--enable-auto-migrations`, `--disable-auto-migrations`
- **Stellar Core**: autostart=true
- **Horizon**: autostart=true, autorestart=true
- **History server**: webfsd started in `start_history_server()` function (not supervisor), port 1570
- **Auto-migrations**: enabled by default (`ENABLE_AUTO_MIGRATIONS=true` in Dockerfile ENV), `--disable-auto-migrations` skips them, `--enable-auto-migrations` accepted for backward compatibility
- **Previous images**: `organization_mainnet-v1.0-p20.2`
- **Supervisor programs**: postgresql, stellar-core, horizon (no webfsd in supervisor)
- **Validator3 port**: must be 31402 (not 31502) in both `/opt/stellar/core/etc/stellar-core.cfg` and `/opt/stellar/horizon/etc/stellar-core-captive.yml`
- **Extra scripts**: `mirror_full_archive.sh`, `horizon_complete_reingest.sh`

## Port Mapping Convention

| Host Port | Container Port | Service |
|-----------|----------------|---------|
| 31401 | 8000 | Horizon API |
| 31402 | 31402 | Stellar Core peer |
| 31403 | 1570 | History archive (relay + organization only) |

## Migration System

- Runner: `/migrations/migration_runner.sh`
- Status tracker: `/opt/stellar/migration_status` (on volume, persists across upgrades)
- Migrations run on every startup before supervisor launches (unless disabled via flag on organization)
- Idempotent: completed migrations tracked by filename, skipped on re-run
- Backups: `/opt/stellar/migration_backups/<timestamp>/`

### Migrations per branch

| # | community | mainnet_relay | organization |
|---|-----------|---------------|--------------|
| 001 | captive_core_upgrade | enable_horizon_auto_migrations | update_validator3 |
| 002 | deprecated_sql_ledger_state | captive_core_migration | captive_core_migration |
| 003 | — | deprecated_sql_ledger_state | fix_validator3_port |
| 004 | — | — | deprecated_sql_ledger_state |

## Volume Layout

All data lives under `/opt/stellar/` (single docker volume mount):

```
/opt/stellar/
├── postgresql/          # DB data + config
│   ├── data/
│   ├── etc/
│   └── .quickstart-initialized
├── core/                # stellar-core config + buckets
│   ├── etc/stellar-core.cfg
│   ├── bin/start
│   ├── buckets/
│   └── .quickstart-initialized
├── horizon/             # horizon config + captive core
│   ├── etc/horizon.env
│   ├── etc/stellar-core-captive.yml
│   ├── bin/start
│   ├── bin/horizon
│   ├── captive-data/
│   └── .quickstart-initialized
├── supervisor/          # supervisord config
│   └── etc/supervisord.conf
├── history/             # (relay + organization only)
│   └── local/
├── migration_status     # tracks completed migrations
└── migration_backups/
```

## Config Defaults

On first run, `copy_defaults` copies from `/opt/stellar-default/` into `/opt/stellar/`. On subsequent runs (volume exists), existing configs are preserved — migrations handle the delta.

- Common defaults: `/opt/stellar-default/common/{postgresql,supervisor,core,horizon}/`
- Network-specific: `/opt/stellar-default/{mainnet,testnet,testnet2,pubnet}/`

## Build

All branches use the same Makefile pattern:

```bash
make build-deps    # builds stellar-core and horizon images from source
make build         # builds the final pi-node-docker image
```

Override versions: `make build CORE_REF=v21.2.0 HORIZON_REF=horizon-v2.32.0 TAG=custom-tag`

## Non-Release Version Warning

Stellar Core logs `Warning: running non-release version` when built from a non-tag commit. Building from a release tag (e.g., `v21.2.0`) embeds the proper version string and avoids this warning. Always use release tags in `CORE_REF`.
