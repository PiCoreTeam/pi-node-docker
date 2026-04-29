# Pi Node Docker Image — Organization

This project provides a Docker image for running Pi Network **organization nodes** — full mainnet nodes with Horizon always-on, a local history archive, and tools for archive management (stellar-archivist, mirror scripts, full reingest).

This image runs in **persistent mode only** — all data and configuration is stored on a mounted volume, ensuring data is preserved between container restarts and allowing configuration customization.

## Software Versions

- **PostgreSQL 16** — stores stellar-core and horizon data (auto-upgraded from PG 12 on first boot; see below)
- **stellar-core 23.0.1** — Pi Network consensus node with local history publishing
- **horizon 23.0.0** — Stellar Horizon API server (captive-core mode, always-on)
- **stellar-archivist** — history archive management tool
- **webfsd** — serves local history archive on port 1570
- **Supervisord** — process manager

## Usage

### 1. Choose a Network

| Flag        | Network            |
|-------------|--------------------|
| `--mainnet` | Pi Network mainnet |

### 2. Mount a Data Volume

You **must** mount a host directory to `/opt/stellar`:

```shell
$ docker run --rm -it \
    -p "31401:8000" \
    -p "31402:31402" \
    -p "31403:1570" \
    -v "/path/to/data:/opt/stellar" \
    --name pi-node \
    pinetwork/pi-node-docker:organization-mainnet-v1.0-p23.0.1-RC1 --mainnet
```

Use a consistent absolute path across restarts.

### 3. Initial Setup

1. Run interactively first to confirm all services start correctly.
2. You will be prompted for a PostgreSQL password (or set `POSTGRES_PASSWORD` env var).
3. Stop the container (Ctrl-C).
4. Restart in background mode using the same volume.

### Customizing Configurations

Default configurations are copied to the data volume on first launch:

```
/opt/stellar
├── core/etc/stellar-core.cfg              # stellar-core config (with [HISTORY.local])
├── horizon/etc/
│   ├── horizon.env                        # Horizon environment variables
│   └── stellar-core-captive.yml           # Horizon captive-core validator config
├── postgresql/etc/postgresql.conf
├── supervisor/etc/supervisord.conf
├── history/local/                         # history archive served by webfsd
├── migration_status                       # Tracks executed migrations
└── migration_backups/                     # Backup files from migrations
```

Stop the container before editing config files, then restart after changes.

## Command Line Options

| Option                      | Description                                              |
|-----------------------------|----------------------------------------------------------|
| `--mainnet`                 | Connect to Pi Network mainnet                            |
| `--disable-auto-migrations` | Skip automatic migration runner on startup               |

## Ports

| Port  | Service         | Description                             |
|-------|-----------------|-----------------------------------------|
| 5432  | postgresql      | Database (do not expose publicly)       |
| 8000  | horizon         | Horizon HTTP API                        |
| 6060  | horizon         | Horizon admin port (trusted only)       |
| 31402 | stellar-core    | Peer port                               |
| 11626 | stellar-core    | HTTP port (internal only)               |
| 1570  | webfsd          | Local history archive                   |

### Recommended Port Mappings

| Host Port | Container Port | Service              |
|-----------|----------------|----------------------|
| 31401     | 8000           | Horizon HTTP         |
| 31402     | 31402          | stellar-core peer    |
| 31403     | 1570           | Local history server |

**Security:** Never expose 5432 publicly. 8000 (horizon) is safe for internet
exposure. 31402 and 1570 can be exposed publicly to improve network
connectivity. Leave 11626 and 6060 unexposed unless accessing admin endpoints
from a trusted network.

## Environment Variables

| Variable            | Default | Description                                                          |
|---------------------|---------|----------------------------------------------------------------------|
| `POSTGRES_PASSWORD` |         | PostgreSQL password (avoids interactive prompt on first run).        |
| `NODE_PRIVATE_KEY`  |         | stellar-core node private key. Auto-generated if not set.            |

## Process Management (Supervisord)

Services are managed by supervisord. **postgresql**, **stellar-core**, and **horizon** all autostart. The history server (webfsd) is started by the `start_history_server()` call in the entrypoint before supervisord launches.

```shell
$ docker exec -it pi-node /bin/bash
$ supervisorctl

supervisor> status
postgresql                       RUNNING    pid 10, uptime 0:02:30
stellar-core                     RUNNING    pid 11, uptime 0:02:30
horizon                          RUNNING    pid 12, uptime 0:02:30

supervisor> restart horizon
supervisor> tail -f stellar-core stdout
```

Services and autostart behavior:

| Service      | Autostart | Notes                                              |
|--------------|-----------|-----------------------------------------------------|
| postgresql   | true      |                                                    |
| stellar-core | true      | publishes history to `/opt/stellar/history/local/` |
| horizon      | true      | always-on; autorestart=true                        |
| webfsd       | entrypoint | started before supervisor, serves port 1570       |

## Migrations

Migration scripts run automatically on every container start (unless `--disable-auto-migrations` is passed) via `/migrations/migration_runner.sh`. Each script is idempotent and tracked in `/opt/stellar/migration_status`. Current migrations:

| ID  | Purpose                                                              |
|-----|----------------------------------------------------------------------|
| 001 | Update validator3 public key                                         |
| 002 | Captive-core upgrade (removes deprecated non-captive config)         |
| 003 | Fix validator3 port (31502 → 31402)                                  |
| 004 | `DEPRECATED_SQL_LEDGER_STATE=false` for stellar-core 21.x            |
| 005 | Fix validator3 key (correct public key)                              |
| 006 | Remove `DEPRECATED_SQL_LEDGER_STATE` and `KNOWN_CURSORS` (v23)       |
| 007 | Update supervisord postgresql command to PG 16 binary                |

### Disabling Migrations

To skip automatic migrations:

```shell
$ docker run -d \
    -v "/path/to/data:/opt/stellar" \
    -p "31401:8000" \
    --name pi-node \
    pinetwork/pi-node-docker:organization-mainnet-v1.0-p23.0.1-RC1 --mainnet --disable-auto-migrations
```

### Running Migrations Manually

```shell
$ docker exec -it pi-node /migrations/migration_runner.sh
```

### Upgrading from `organization-mainnet-v1.0-p22.1-RC1` (PG 12) to `organization-mainnet-v1.0-p23.0.1-RC1` (PG 16)

Upgrading an existing volume is seamless:

1. Stop the old container.
2. Start the new image with the **same volume path**.
3. On first boot: PG 12 cluster is auto-upgraded to PG 16 via `pg_upgrade --link`,
   and migrations 006–007 run (remove deprecated stellar-core v23 settings, update PG16 binary in supervisord).
4. All services resume automatically (postgresql, stellar-core, horizon).

No data is lost; the old core/horizon/history volumes are reused.

The pre-upgrade v12 directory is preserved at
`/opt/stellar/postgresql/data.pg12.bak`. After verifying the node is healthy,
you may `rm -rf /opt/stellar/postgresql/data.pg12.bak` to reclaim space.

## Archive Management Tools

The image includes scripts for managing the local history archive:

- **`mirror_full_archive.sh`** — mirrors the full Pi mainnet history archive locally
- **`horizon_complete_reingest.sh`** — triggers a complete Horizon ledger reingest

Run them inside the container:

```shell
$ docker exec -it pi-node mirror_full_archive.sh
$ docker exec -it pi-node horizon_complete_reingest.sh
```

## Example Launch Commands

*Mainnet organization node (interactive, first-time setup):*
```shell
$ docker run --rm -it \
    -p "31401:8000" \
    -p "31402:31402" \
    -p "31403:1570" \
    -v "/opt/pi-org:/opt/stellar" \
    -e POSTGRES_PASSWORD=yourpassword \
    --name pi-org \
    pinetwork/pi-node-docker:organization-mainnet-v1.0-p23.0.1-RC1 --mainnet
```

*Mainnet organization node (background, after initialization):*
```shell
$ docker run -d \
    -p "31401:8000" \
    -p "31402:31402" \
    -p "31403:1570" \
    -v "/opt/pi-org:/opt/stellar" \
    -e POSTGRES_PASSWORD=yourpassword \
    --name pi-org \
    pinetwork/pi-node-docker:organization-mainnet-v1.0-p23.0.1-RC1 --mainnet
```

## Node Status

The image includes a built-in `node-status` command:

```shell
$ docker exec pi-org node-status
```

Available flags: `--services`, `--protocol`, `--horizon`, `--peers`, `--system`. No flags show all sections.

See [node-status/node-status.md](node-status/node-status.md) for full documentation.

## Building the Image

```shell
$ make build-deps   # build stellar-core and horizon from source
$ make build        # build the final image
```

This builds the image as `pinetwork/pi-node-docker:organization-mainnet-v1.0-p23.0.1-RC1`.

## Troubleshooting

If you encounter issues, open an issue in the repository.
