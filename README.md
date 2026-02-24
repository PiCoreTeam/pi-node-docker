# Pi Node Docker Image

This project provides a Docker image for running Pi Network nodes, including stellar-core and horizon services.

This image runs in **persistent mode**, storing all data and configuration on a mounted volume. This ensures data is preserved between container restarts and allows for configuration customization.

## Software Versions

The image uses the following software:

- **PostgreSQL 12** - for storing both stellar-core and horizon data
- **stellar-core** 20.2.0
- **horizon** 2.30.0
- **Supervisord** - for managing the processes of the services above
- **stellar-archivist** - for managing history archives(optional scripts)

## Usage

To use this project successfully, you should first decide a few things:

### 1. Choose a Network

- **`--mainnet`** - Pi Network mainnet (production network)

### 2. Choose Ports to Expose

The software listens on several ports. At minimum, expose the horizon HTTP port (8000). See the "Ports" section below for details.

### 3. Mount a Data Volume

You **must** mount a host directory to `/opt/stellar` to store persistent data:

```shell
$ docker run --rm -it -p "31401:8000" -v "/path/to/data:/opt/stellar" --name pi-node pinetwork/pi-node-docker:organization_mainnet-v1.0-p20.2 --mainnet
```

The `-v` option mounts the host directory into the container at `/opt/stellar`. Use an absolute path and keep it consistent across container restarts.

### Background vs. Interactive Containers

Docker containers can be run interactively (using the `-it` flags) or in a detached, background state (using the `-d` flag). Many of the example commands below use the `-it` flags to aid in debugging but in many cases you will simply want to run a node in the background. It's recommended that you familiarize yourself with [Docker tutorials](https://docs.docker.com/engine/tutorials/usingdocker/).

### Initial Setup

1. Run an interactive session first, ensuring all services start correctly.
2. You will be prompted to set a PostgreSQL password (or set `POSTGRES_PASSWORD` environment variable).
3. Shut down the interactive container (using Ctrl-C).
4. Start a new container using the same host directory in the background.

### Customizing Configurations

Default configurations are copied to the data directory on first launch:

```
/opt/stellar
├── core
│   └── etc
│       └── stellar-core.cfg    # stellar-core configuration
├── horizon
│   └── etc
│       └── horizon.env         # Horizon environment variables
├── postgresql
│   └── etc
│       ├── postgresql.conf     # PostgreSQL configuration
│       ├── pg_hba.conf         # PostgreSQL client authentication
│       └── pg_ident.conf       # PostgreSQL user mapping
├── supervisor
│   └── etc
│       └── supervisord.conf    # Supervisord configuration
├── migration_status            # Tracks executed migrations (auto-created)
└── migration_backups/          # Backup files from migrations (auto-created)
```

Stop the container before editing configuration files, then restart after changes.

**WARNING:** Incorrect configuration edits can break services. Understand each service before customizing.


## Command Line Options

| Option                     | Description                               |
|----------------------------|-------------------------------------------|
| `--mainnet`                | Connect to Pi Network mainnet             |
| `--enable-auto-migrations` | Run database/config migrations on startup |

## Environment Variables

| Variable            | Description                                                                         |
|---------------------|-------------------------------------------------------------------------------------|
| `POSTGRES_PASSWORD` | Set PostgreSQL password (avoids interactive prompt)                                 |
| `NODE_PRIVATE_KEY`  | Set the node's private key (secret seed). Optional - auto-generated if not provided |

## Migrations

The container includes migration scripts that update database schemas, modify deprecated configuration parameters, and apply other necessary changes when upgrading to newer versions. Migrations run automatically on startup when enabled with `--enable-auto-migrations`.

### How It Works

- Migration scripts are located in `/migrations/` inside the container
- Scripts execute in alphanumeric order (e.g., `001_*.sh`, `002_*.sh`, ...)
- Each script runs only once - completed migrations are tracked in `/opt/stellar/migration_status`
- If a migration fails, the container stops immediately (fail-fast)
- Failed migrations will re-run on next startup
- Backups are created in `/opt/stellar/migration_backups/` before changes

### Enabling Migrations

Add `--enable-auto-migrations` to your container command:

```shell
$ docker run -d \
    -v "/path/to/data:/opt/stellar" \
    -p "31401:8000" \
    --name pi-node \
    pinetwork/pi-node-docker:organization_mainnet-v1.0-p20.2 --mainnet --enable-auto-migrations
```

### Running Migrations Manually

You can also run migrations manually inside a running container:

```shell
$ docker exec -it pi-node /migrations/migration_runner.sh
```

Or invoke a specific migration script:

```shell
$ docker exec -it pi-node /migrations/001_update_validator3.sh
```

If you prefer not to rely on scripts and want to manage configuration changes manually, you can find step-by-step documentation in the [migrations/docs](migrations/docs) folder.

## Ports

| Port  | Service      | Description              |
|-------|--------------|--------------------------|
| 5432  | PostgreSQL   | Database access port     |
| 8000  | Horizon      | Main HTTP port           |
| 6060  | Horizon      | Admin port               |
| 31402 | stellar-core | Peer node port           |
| 11626 | stellar-core | HTTP port (internal)     |
| 1570  | webfsd       | Local history server     |

### Recommended Port Mappings

| Host Port | Container Port | Service              |
|-----------|----------------|----------------------|
| 31401     | 8000           | Horizon HTTP         |
| 31402     | 31402          | stellar-core peer    |
| 31403     | 1570           | Local history server |

### Security Considerations

- **PostgreSQL (5432):** Keep protected. An attacker with write access can corrupt your view of the network.
- **Horizon HTTP (8000):** Safe to expose publicly. Designed for internet-facing use.
- **Horizon Admin (6060):** Expose only to trusted networks.
- **stellar-core HTTP (11626):** Expose only to trusted networks. Allows administrative commands.
- **stellar-core Peer (31402):** Can be exposed publicly to improve network connectivity.
- **Local history (1570):** Used for serving local history archives.

## Accessing and Debugging

Access a running container:

```shell
$ docker exec -it pi-node bash
```

### Managing Services

Services are managed using [supervisord](http://supervisord.org/index.html). Launch the supervisor shell:

```shell
$ supervisorctl
horizon                          RUNNING    pid 143, uptime 0:01:12
postgresql                       RUNNING    pid 126, uptime 0:01:13
stellar-core                     RUNNING    pid 125, uptime 0:01:13
supervisor>
```

Common commands:

```shell
supervisor> restart horizon
supervisor> stop stellar-core
supervisor> help
```

### Viewing Logs

Logs are located at `/var/log/supervisor/`. Use `supervisorctl tail` for live logs.

### Accessing Databases

This image manages two PostgreSQL databases:

- **`core`** - stellar-core data
- **`horizon`** - Horizon data

Connect using:
- **Username:** `stellar`
- **Password:** The password you set during initial setup (or via `POSTGRES_PASSWORD` env var)

## Example Commands

**Initialize a new mainnet node (interactive, for initial setup):**
```shell
$ docker run -it --rm \
    -v "/path/to/data:/opt/stellar" \
    -p "31401:8000" \
    -p "31402:31402" \
    -p "31403:1570" \
    --name pi-node \
    pinetwork/pi-node-docker:organization_mainnet-v1.0-p20.2 --mainnet
```

**Start a mainnet node in the background (after initialization):**
```shell
$ docker run -d \
    -v "/path/to/data:/opt/stellar" \
    -p "31401:8000" \
    -p "31402:31402" \
    -p "31403:1570" \
    --name pi-node \
    pinetwork/pi-node-docker:organization_mainnet-v1.0-p20.2 --mainnet
```

**Start with pre-set PostgreSQL password (non-interactive):**
```shell
$ docker run -d \
    -v "/path/to/data:/opt/stellar" \
    -p "31401:8000" \
    -p "31402:31402" \
    -p "31403:1570" \
    -e POSTGRES_PASSWORD=your_secure_password \
    --name pi-node \
    pinetwork/pi-node-docker:organization_mainnet-v1.0-p20.2 --mainnet
```

## Docker Compose

Recommended `docker-compose.yml` configuration:

```yaml
name: pi-node

services:
  mainnet:
    image: pinetwork/pi-node-docker:organization_mainnet-v1.0-p20.2
    container_name: mainnet
    env_file:
      - ./.env
    volumes:
      - ./data/stellar:/opt/stellar
      - ./data/supervisor_logs:/var/log/supervisor
      - ./data/history:/history
    ports:
      - "31401:8000"
      - "31402:31402"
      - "31403:1570"
    command: ["--mainnet --enable-auto-migrations"]
```

Create a `.env` file with your configuration:

```shell
POSTGRES_PASSWORD=your_secure_password
NODE_PRIVATE_KEY=your_node_private_key  # Optional - auto-generated if not provided
```

Start the node:

```shell
$ docker compose up -d mainnet
```

## Building the Image

```shell
$ make build
```

This builds the image as `pinetwork/pi-node-docker:organization_mainnet-v1.0-p20.2`.

## Troubleshooting

If you encounter issues, open an issue in the repository.
