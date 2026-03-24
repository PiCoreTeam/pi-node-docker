# Community Node Testing Guide

Image: `pinetwork/pi-node-docker:community-v1.1-p21.2`

| Component      | Version             |
|----------------|---------------------|
| Stellar Core   | v21.2.0             |
| Horizon        | v2.32.0             |
| PostgreSQL     | 12                  |

## Requirements

1. **Fresh initialization** — Image must initialize successfully from scratch (no pre-existing volume)
2. **Volume compatibility** — Image must start successfully when using a docker-volume from a previous community image (`community-v1.0-p19.9`, `community-v1.0-p20.2`)
3. **Auto-migration** — Container must automatically detect and run pending migrations on startup when reusing volumes from older images
4. **Stellar Core starts by default** — stellar-core must auto-start and begin syncing
5. **Horizon disabled by default** — horizon must not auto-start, but `supervisorctl start horizon` must start it and it must be functional during that run, no autostart after container restart
6. **No non-release version warning** — stellar-core logs must not contain `Warning: running non-release version`

## Useful Commands

```bash
# Start container (testnet2)
docker compose up -d mainnet

# Or run directly
docker run -d --name pi-community \
  -p 8000:8000 \
  -p 31402:31402 \
  -e POSTGRES_PASSWORD=postgres \
  pinetwork/pi-node-docker:community-v1.1-p21.2 --testnet2

# Check service status
docker exec pi-community supervisorctl status

# Check stellar-core sync state
docker exec pi-community stellar-core --conf /opt/stellar/core/etc/stellar-core.cfg http-command info

# Start horizon on-demand
docker exec pi-community supervisorctl start horizon

# Stop horizon
docker exec pi-community supervisorctl stop horizon

# Check horizon API
curl -s http://localhost:31401/ | jq '{horizon_version, core_version, history_latest_ledger, core_latest_ledger}'

# Check migration status
docker exec pi-community cat /opt/stellar/migration_status

# View logs
docker exec pi-community cat /var/log/supervisor/supervisord.log
docker exec pi-community cat /var/log/supervisor/stellar-core-stdout*.log
docker exec pi-community cat /var/log/supervisor/horizon-stdout*.log

# Teardown
docker compose down
docker volume prune
```

## Test Docker Compose

Use this to test volume compatibility between previous and current images.
Run `current` first to initialize, stop it, then run `next` to verify upgrade + auto-migration.

```yaml
services:
  pi-community-testnet2-current:
    image: pinetwork/pi-node-docker:community-v1.0-p20.2
    container_name: pi-community-testnet2-current
    command: --testnet2
    ports:
      - "31401:8000"
      - "31402:31402"
    environment:
      POSTGRES_PASSWORD: postgres
    volumes:
      - pi-community-testnet2-data:/opt/stellar

  pi-community-testnet2-next:
    image: pinetwork/pi-node-docker:community-v1.1-p21.2
    container_name: pi-community-testnet2-next
    command: --testnet2
    ports:
      - "31401:8000"
      - "31402:31402"
    environment:
      POSTGRES_PASSWORD: postgres
    volumes:
      - pi-community-testnet2-data:/opt/stellar

volumes:
  pi-community-testnet2-data:
```
