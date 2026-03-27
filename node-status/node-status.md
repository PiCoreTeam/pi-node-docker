# node-status

Lightweight bash script that shows Pi Network node status from inside the Docker container. Minimal alternative to `pi-node status`.

## Usage

From the host:

```bash
docker exec pi-consensus-container node-status
docker exec pi-consensus-container node-status --protocol --horizon
```

From inside the container:

```bash
node-status
node-status --horizon
```

## Flags

| Flag           | Section                                     |
|----------------|---------------------------------------------|
| `--services`   | Supervisord service states                  |
| `--protocol`   | Protocol state, block, network              |
| `--horizon`    | Horizon sync state, blocks, ingest progress |
| `--peers`      | Peer connection counts                      |
| `--system`     | Disk, RAM, CPU                              |
| `-h, --help`   | Usage info                                  |

No flags = all sections.

## Horizon state

State is derived from `core_latest_ledger` and `ingest_latest_ledger` reported by the Horizon API:

- **Catching Up** — node is bootstrapping, both captive core and ingest ledgers are at zero. This is expected on first start and can take a significant amount of time depending on network and hardware
- **Not Running** — Horizon API is not responding
- **Syncing** — ingest is running but still behind core; progress details are shown when available
- **Synced** — core and ingest are within 5 ledgers of each other

## Requirements

`bash`, `jq`, `curl`, `supervisorctl` — all available in the container.

## Location

Deployed to `/usr/local/bin/node-status` inside the container.

## Data sources

- **Services** — `supervisorctl status`
- **Protocol** — `http://localhost:11626/info`
- **Horizon** — `http://localhost:8000/`
- **Peers** — `http://localhost:11626/peers`
- **System** — `/proc/meminfo`, `/proc/stat`, `df`, `nproc`

## Error handling

Each section is independent. If an endpoint is down, that section shows "Not responding" and the rest still work. If `jq` is missing, the script exits immediately.
