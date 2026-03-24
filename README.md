# Pi Node Docker Image

This project provides a Docker image for running Pi Network nodes, including stellar-core and horizon services.

This image runs in **persistent mode only** — all data and configuration is stored on a mounted volume, ensuring data is preserved between container restarts and allowing configuration customization.

## Software Versions

- **PostgreSQL 12** — stores both stellar-core and horizon data
- **stellar-core 21.2** — Pi Network consensus node
- **horizon 2.30** — Stellar Horizon API server (captive-core mode)
- **Supervisord** — process manager
- **webfsd** — serves local history archive (mainnet only, port 1570)

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
    -p "31402:31402" \
    -v "/path/to/data:/opt/stellar" \
    --name pi-node \
    pinetwork/pi-node-docker:community-v1.1-p21.2 --mainnet
```

Use a consistent absolute path across restarts. The second portion (`/opt/stellar`) must not change.

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
│   └── stellar-core-captive.yml      # Captive core validator config
├── postgresql/etc/postgresql.conf
├── supervisor/etc/supervisord.conf
├── migration_status                   # Tracks executed migrations
└── migration_backups/                 # Backup files from migrations
```

Stop the container before editing config files, then restart after changes.

## Ports

| Port  | Service      | Description                            |
|-------|--------------|----------------------------------------|
| 5432  | postgresql   | Database (do not expose publicly)      |
| 8000  | horizon      | Main HTTP API port                     |
| 6060  | horizon      | Admin port (trusted networks only)     |
| 31402 | stellar-core | Peer port                              |
| 1570  | webfsd       | Local history archive (mainnet only)   |

**Security:** Never expose port 5432 publicly. Port 8000 is safe for internet exposure. Port 31402 can be exposed to improve overlay connectivity.

## Environment Variables

| Variable            | Description                                                          |
|---------------------|----------------------------------------------------------------------|
| `POSTGRES_PASSWORD` | Sets PostgreSQL password (avoids interactive prompt on first run)    |
| `NODE_PRIVATE_KEY`  | Node private key (secret seed). Auto-generated if not provided.      |

## Process Management (Supervisord)

Services are managed by supervisord. stellar-core starts automatically; horizon does **not** start automatically (it must be started manually or via supervisorctl after stellar-core has caught up).

```shell
# Open a shell into a running container
$ docker exec -it pi-node /bin/bash

# Launch supervisorctl
$ supervisorctl

# Example commands
supervisor> status
supervisor> start horizon
supervisor> restart stellar-core
supervisor> tail -f horizon stderr
```

Services and autostart behavior:

| Service      | Autostart | Notes                              |
|--------------|-----------|------------------------------------|
| postgresql   | true      |                                    |
| stellar-core | true      |                                    |
| webfsd       | true      | Serves history on port 1570        |
| horizon      | false     | Start manually after core sync     |

## Migrations

Migration scripts run automatically on every container start via `/migrations/migration_runner.sh`. Each script is idempotent and tracked in `/opt/stellar/migration_status`.

## Example Launch Commands

*Mainnet node (interactive, first-time setup):*
```shell
$ docker run --rm -it \
    -p "8000:8000" \
    -p "31402:31402" \
    -v "/opt/pi-node:/opt/stellar" \
    -e POSTGRES_PASSWORD=yourpassword \
    --name pi-node \
    pinetwork/pi-node-docker:community-v1.1-p21.2 --mainnet
```

*Mainnet node (background, after initialization):*
```shell
$ docker run -d \
    -p "8000:8000" \
    -p "31402:31402" \
    -v "/opt/pi-node:/opt/stellar" \
    -e POSTGRES_PASSWORD=yourpassword \
    --name pi-node \
    pinetwork/pi-node-docker:community-v1.1-p21.2 --mainnet
```

*Testnet node:*
```shell
$ docker run -d \
    -p "8000:8000" \
    -v "/opt/pi-testnet:/opt/stellar" \
    -e POSTGRES_PASSWORD=yourpassword \
    --name pi-testnet \
    pinetwork/pi-node-docker:community-v1.1-p21.2 --testnet
```

## Viewing Logs

Logs are at `/var/log/supervisor/` inside the container. Use `supervisorctl tail -f <service> stdout` for live output.
