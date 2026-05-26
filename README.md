# Pi Node Docker Image

This project provides a Docker image for running Pi Network nodes, including
stellar-core, horizon, and stellar-rpc (Soroban RPC) services.

This image runs in **persistent mode only** — all data and configuration is
stored on a mounted volume, ensuring data is preserved between container
restarts and allowing configuration customization.

## Software Versions

- **PostgreSQL 16** — stores stellar-core and horizon data (auto-upgraded from PG 12 on first boot; see below)
- **stellar-core 23.0.1** — Pi Network consensus node
- **horizon 23.0.0** — Stellar Horizon API server (captive-core mode)
- **stellar-rpc 23.0.4** — Soroban JSON-RPC server (captive-core mode, sqlite backend)
- **Supervisord** — process manager

## Usage

### 1. Choose a Network

| Flag          | Network              | Passphrase       |
|---------------|----------------------|------------------|
| `--mainnet`   | Pi Network mainnet   | `Pi Network`     |
| `--testnet`   | Pi Testnet           | `Pi Testnet`     |
| `--testnet2`  | Pi Testnet 2         | `Pi Testnet`     |

### 2. Mount a Data Volume

You **must** mount a host directory to `/opt/stellar`:

```shell
$ docker run --rm -it \
    -p "8000:8000" \
    -p "8003:8003" \
    -p "31402:31402" \
    -v "/path/to/data:/opt/stellar" \
    --name pi-node \
    pinetwork/pi-node-docker:community-v1.0-p25.2.2 --mainnet
```

Use a consistent absolute path across restarts. The second portion
(`/opt/stellar`) must not change.

### 3. Initial Setup

1. Run interactively first to confirm all services start correctly.
2. You will be prompted for a PostgreSQL password (or set `POSTGRES_PASSWORD` env var).
3. Stop the container (Ctrl-C).
4. Restart in background mode using the same volume.

### Customizing Configurations

Default configurations are copied to the data volume on first launch:

```
/opt/stellar
├── core/etc/stellar-core.cfg          # stellar-core config
├── horizon/etc/
│   ├── horizon.env                    # Horizon environment variables
│   └── stellar-core-captive.yml       # Horizon captive-core validator config
├── stellar-rpc/etc/
│   ├── stellar-rpc.cfg                # stellar-rpc config
│   └── stellar-captive-core.cfg       # stellar-rpc captive-core config
├── postgresql/etc/postgresql.conf
├── supervisor/etc/supervisord.conf
├── migration_status                   # Tracks executed migrations
└── migration_backups/                 # Backup files from migrations
```

Stop the container before editing config files, then restart after changes.

## Ports

| Port  | Service         | Description                             |
|-------|-----------------|-----------------------------------------|
| 5432  | postgresql      | Database (do not expose publicly)       |
| 8000  | horizon         | Horizon HTTP API                        |
| 6060  | horizon         | Horizon admin port (trusted only)       |
| 8003  | stellar-rpc     | Soroban JSON-RPC endpoint               |
| 6061  | stellar-rpc     | stellar-rpc admin port (opt-in)         |
| 11826 | stellar-rpc     | captive-core HTTP (internal only)       |
| 31402 | stellar-core    | Peer port                               |

**Security:** Never expose 5432 publicly. 8000 (horizon) and 8003 (stellar-rpc)
are safe for internet exposure. 31402 can be exposed to improve overlay
connectivity. Leave 11826 and 6060/6061 unexposed unless intentionally
accessing admin endpoints from a trusted network.

## Environment Variables

| Variable                      | Default | Description                                                   |
|-------------------------------|---------|---------------------------------------------------------------|
| `POSTGRES_PASSWORD`           |         | PostgreSQL password (avoids interactive prompt on first run). |
| `NODE_PRIVATE_KEY`            |         | stellar-core node private key. Auto-generated if not set.     |
| `ENABLE_RPC_ADMIN_ENDPOINT`   | `false` | Bind stellar-rpc admin endpoint to `0.0.0.0:6061` when true.  |

## Process Management (Supervisord)

Services are managed by supervisord. Only **postgres** and **stellar-core**
autostart. **horizon** and **rpc** must be started manually after
stellar-core has caught up.

```shell
# Open a shell into a running container
$ docker exec -it pi-node /bin/bash

# Launch supervisorctl
$ supervisorctl

# Example commands
supervisor> status
supervisor> start horizon
supervisor> start rpc
supervisor> restart stellar-core
supervisor> tail -f rpc stdout
```

Services and autostart behavior:

| Service      | Autostart | Notes                                     |
|--------------|-----------|-------------------------------------------|
| postgresql   | true      |                                           |
| stellar-core | true      |                                           |
| horizon      | false     | Start manually after core sync            |
| rpc          | false     | Start manually after core sync (stellar-rpc) |

## Migrations

Migration scripts run automatically on every container start via
`/migrations/migration_runner.sh`. Each script is idempotent and tracked in
`/opt/stellar/migration_status`. Current migrations:

| ID  | Purpose                                                              |
|-----|----------------------------------------------------------------------|
| 001 | Captive-core upgrade                                                 |
| 002 | `DEPRECATED_SQL_LEDGER_STATE=false` for stellar-core 21.x            |
| 003 | Remove deprecated settings for stellar-core 23.x                     |
| 004 | Register `rpc` supervisord program on existing volumes               |

### Upgrading from an older community release

Upgrading an existing volume (e.g., `community-v1.1-p21.2` or
`community-v1.0-p22.1`) is seamless:

1. Stop the old container.
2. Start the new image with the **same volume path**.
3. On first boot: the start script copies the `stellar-rpc/` default tree into
   the volume (since it doesn't exist yet), initializes its configs with your
   network values, and migration 004 appends the `[program:rpc]` block to
   your existing `supervisord.conf`.
4. Once stellar-core has caught up, `supervisorctl start horizon` and
   `supervisorctl start rpc` as needed.

No data is lost; the old core/horizon volumes are reused.

## Example Launch Commands

*Mainnet node (interactive, first-time setup):*
```shell
$ docker run --rm -it \
    -p "8000:8000" \
    -p "8003:8003" \
    -p "31402:31402" \
    -v "/opt/pi-node:/opt/stellar" \
    -e POSTGRES_PASSWORD=yourpassword \
    --name pi-node \
    pinetwork/pi-node-docker:community-v1.0-p25.2.2 --mainnet
```

*Mainnet node (background, after initialization):*
```shell
$ docker run -d \
    -p "8000:8000" \
    -p "8003:8003" \
    -p "31402:31402" \
    -v "/opt/pi-node:/opt/stellar" \
    -e POSTGRES_PASSWORD=yourpassword \
    --name pi-node \
    pinetwork/pi-node-docker:community-v1.0-p25.2.2 --mainnet
```

*Testnet node:*
```shell
$ docker run -d \
    -p "8000:8000" \
    -p "8003:8003" \
    -v "/opt/pi-testnet:/opt/stellar" \
    -e POSTGRES_PASSWORD=yourpassword \
    --name pi-testnet \
    pinetwork/pi-node-docker:community-v1.0-p25.2.2 --testnet
```

## Viewing Logs

Logs are at `/var/log/supervisor/` inside the container. Use
`supervisorctl tail -f <service> stdout` for live output.

## Upgrading from `community-v1.0-p22.1` (PG 12) to `community-v1.0-p25.2.2` (PG 16)

On first boot against a `/opt/stellar` volume whose PostgreSQL cluster is still
on version 12, the container detects the old cluster and runs `pg_upgrade --link`
automatically before any service starts. After the upgrade, supervisord launches
the cluster on PostgreSQL 16 and the node resumes catchup.

The pre-upgrade v12 directory is preserved at
`/opt/stellar/postgresql/data.pg12.bak` for forensic inspection. **It is not a
safe rollback target:** `pg_upgrade --link` hardlinks relfiles into the new
cluster, and `pg_control` is renamed in the old directory. Once the PG 16
cluster has booted even once, the only supported rollback is restoring the
entire `/opt/stellar` volume from a pre-upgrade backup. Take that backup before
launching the new image.

After you have verified the node is healthy, you may `rm -rf
/opt/stellar/postgresql/data.pg12.bak` to reclaim the space.

For local migration testing against a seeded PG 12 data set, see
`internal/volumes/` (data is gitignored; the seed/clone/run scripts are in-repo).
