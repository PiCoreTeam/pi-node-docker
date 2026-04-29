# Pi Node Docker Image — Relay

This project provides a Docker image for running Pi Network **relay nodes** — mainnet nodes that publish a local history archive, enabling other nodes to catch up from this peer.

This image runs in **persistent mode only** — all data and configuration is stored on a mounted volume, ensuring data is preserved between container restarts and allowing configuration customization.

## Software Versions

- **PostgreSQL 16** — stores stellar-core and horizon data (auto-upgraded from PG 12 on first boot; see below)
- **stellar-core 23.0.1** — Pi Network consensus node with local history publishing
- **horizon 23.0.0** — Stellar Horizon API server (captive-core mode, off by default)
- **stellar-rpc 23.0.4** — Soroban JSON-RPC server (off by default)
- **webfsd** — serves local history archive on port 1570
- **Supervisord** — process manager

## Usage

### 1. Choose a Network

| Flag              | Network            |
|-------------------|--------------------|
| `--mainnetrelay`  | Pi Network mainnet |

### 2. Mount a Data Volume

You **must** mount a host directory to `/opt/stellar`:

```shell
$ docker run --rm -it \
    -p "31401:8000" \
    -p "31402:31402" \
    -p "31403:1570" \
    -v "/path/to/data:/opt/stellar" \
    --name pi-node \
    pinetwork/pi-node-docker:relay-v1.0-p23.0.1 --mainnetrelay
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
├── stellar-rpc/etc/
│   ├── stellar-rpc.cfg                    # stellar-rpc config
│   └── stellar-captive-core.cfg           # stellar-rpc captive-core config
├── postgresql/etc/postgresql.conf
├── supervisor/etc/supervisord.conf
├── history/local/                         # history archive served by webfsd
├── migration_status                       # Tracks executed migrations
└── migration_backups/                     # Backup files from migrations
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
| 1570  | webfsd          | Local history archive                   |

### Recommended Port Mappings

| Host Port | Container Port | Service              |
|-----------|----------------|----------------------|
| 31401     | 8000           | Horizon HTTP         |
| 31402     | 31402          | stellar-core peer    |
| 31403     | 1570           | Local history server |

**Security:** Never expose 5432 publicly. 8000 (horizon) and 8003 (stellar-rpc)
are safe for internet exposure. 31402 and 1570 can be exposed publicly to
improve network connectivity and allow peers to use this archive. Leave 11826
and 6060/6061 unexposed unless accessing admin endpoints from a trusted network.

## Environment Variables

| Variable                      | Default | Description                                                    |
|-------------------------------|---------|----------------------------------------------------------------|
| `POSTGRES_PASSWORD`           |         | PostgreSQL password (avoids interactive prompt on first run).  |
| `NODE_PRIVATE_KEY`            |         | stellar-core node private key. Auto-generated if not set.      |
| `ENABLE_RPC_ADMIN_ENDPOINT`   | `false` | Bind stellar-rpc admin endpoint to `0.0.0.0:6061` when true.  |

## Process Management (Supervisord)

Services are managed by supervisord. **postgresql**, **stellar-core**, and **webfsd** autostart. **horizon** and **rpc** must be started manually after stellar-core has caught up.

```shell
$ docker exec -it pi-node /bin/bash
$ supervisorctl

supervisor> status
postgresql                       RUNNING    pid 10, uptime 0:02:30
stellar-core                     RUNNING    pid 11, uptime 0:02:30
webfsd                           RUNNING    pid 12, uptime 0:02:30
horizon                          STOPPED    Not started
rpc                              STOPPED    Not started

supervisor> start horizon
supervisor> start rpc
supervisor> tail -f stellar-core stdout
```

Services and autostart behavior:

| Service      | Autostart | Notes                                              |
|--------------|-----------|-----------------------------------------------------|
| postgresql   | true      |                                                    |
| stellar-core | true      | publishes history to `/opt/stellar/history/local/` |
| webfsd       | true      | serves history archive on port 1570                |
| horizon      | false     | Start manually after core sync                     |
| rpc          | false     | Start manually after core sync (stellar-rpc)       |

## Migrations

Migration scripts run automatically on every container start via
`/migrations/migration_runner.sh`. Each script is idempotent and tracked in
`/opt/stellar/migration_status`. Current migrations:

| ID  | Purpose                                                              |
|-----|----------------------------------------------------------------------|
| 001 | Enable Horizon auto-migrations flag                                  |
| 002 | Captive-core upgrade (removes deprecated non-captive config)         |
| 003 | `DEPRECATED_SQL_LEDGER_STATE=false` for stellar-core 21.x            |
| 004 | Register `rpc` supervisord program on existing volumes               |
| 005 | Update supervisord postgresql command to PG 16 binary                |
| 006 | Remove `DEPRECATED_SQL_LEDGER_STATE` and `KNOWN_CURSORS` (v23)       |

### Upgrading from `mainnet-relay-v1.0-p22.1` (PG 12) to `relay-v1.0-p23.0.1` (PG 16)

Upgrading an existing volume is seamless:

1. Stop the old container.
2. Start the new image with the **same volume path**.
3. On first boot: PG 12 cluster is auto-upgraded to PG 16 via `pg_upgrade --link`,
   stellar-rpc defaults are copied into the volume, and migrations 004–006 run.
4. Once stellar-core has caught up, start horizon and/or rpc via supervisorctl as needed.

No data is lost; the old core/horizon/history volumes are reused.

The pre-upgrade v12 directory is preserved at
`/opt/stellar/postgresql/data.pg12.bak`. After verifying the node is healthy,
you may `rm -rf /opt/stellar/postgresql/data.pg12.bak` to reclaim space.

## Example Launch Commands

*Mainnet relay node (interactive, first-time setup):*
```shell
$ docker run --rm -it \
    -p "31401:8000" \
    -p "31402:31402" \
    -p "31403:1570" \
    -v "/opt/pi-relay:/opt/stellar" \
    -e POSTGRES_PASSWORD=yourpassword \
    --name pi-relay \
    pinetwork/pi-node-docker:relay-v1.0-p23.0.1 --mainnetrelay
```

*Mainnet relay node (background, after initialization):*
```shell
$ docker run -d \
    -p "31401:8000" \
    -p "31402:31402" \
    -p "31403:1570" \
    -v "/opt/pi-relay:/opt/stellar" \
    -e POSTGRES_PASSWORD=yourpassword \
    --name pi-relay \
    pinetwork/pi-node-docker:relay-v1.0-p23.0.1 --mainnetrelay
```

## Node Status

The image includes a built-in `node-status` command:

```shell
$ docker exec pi-relay node-status
```

Available flags: `--services`, `--protocol`, `--horizon`, `--peers`, `--system`. No flags show all sections.

See [node-status/node-status.md](node-status/node-status.md) for full documentation.

## Building the Image

```shell
$ make build-deps   # build stellar-core, horizon, and stellar-rpc from source
$ make build        # build the final image
```

This builds the image as `pinetwork/pi-node-docker:relay-v1.0-p23.0.1`.

## Troubleshooting

If you encounter issues, open an issue in the repository.
