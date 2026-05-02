# Triumph Synergy Digital Financial Ecosystem — Integration

**Repository:** https://github.com/jdrains110-beep/Triumph-Synergy-Digital-Financial-Ecosystem  
**Image used:** `pinetwork/pi-node-docker:organization-mainnet-v1.0-p23.0.1`  
**Node role:** Sovereign on-chain anchor (replaces third-party API endpoints)

## Overview

The Triumph Synergy Digital Financial Ecosystem runs `pi-node-docker` as
its **primary sovereign Pi mainnet node**. All payment rails, settlement,
tokenization, and payroll flows settle against this self-hosted node
rather than a third-party API, ensuring full sovereign control.

Services that depend on this node:

| Service | Port | Role |
|---------|------|------|
| pi-bridge-connector | 8092 | Pi Network bridge |
| settlement-core | 8080 | T+0 settlement |
| tokenization-engine | 8085 | Asset tokenization |
| sovereign-work-nexus | 8132 | Global jobs + Pi payroll |
| publix-phygital-hub | 8133 | Phygital retail Pi payments |

## docker-compose snippet

```yaml
pi-mainnet-node:
  image: pinetwork/pi-node-docker:organization-mainnet-v1.0-p23.0.1
  container_name: triumph-pi-mainnet-node
  restart: unless-stopped
  environment:
    POSTGRES_PASSWORD: ${PI_NODE_POSTGRES_PASSWORD}
    NODE_PRIVATE_KEY:  ${PI_NODE_PRIVATE_KEY:-}
  volumes:
    - pi_mainnet_stellar:/opt/stellar
    - pi_mainnet_logs:/var/log/supervisor
    - pi_mainnet_history:/history
  ports:
    - "31401:8000"   # Horizon HTTP API
    - "31402:31402"  # stellar-core peer
    - "31403:1570"   # local history server
  command: ["--mainnet"]
  networks:
    - triumph-net
    - pi-bridge
```

## .env additions

```env
PI_NODE_POSTGRES_PASSWORD=<strong-password>
PI_NODE_PRIVATE_KEY=          # leave blank for auto-generation
PI_NODE_HORIZON_PORT=31401
PI_NODE_PEER_PORT=31402
PI_NODE_HISTORY_PORT=31403
```

## Node-status check

```bash
docker exec triumph-pi-mainnet-node node-status
```

## Upgrade notes

Before upgrading to a new image version, stop the container and snapshot
the `pi_mainnet_stellar` Docker volume (pg_upgrade rewrites in place).
Per the [v1.0-p23.0.1 release notes](https://github.com/jdrains110-beep/Triumph-Synergy-Digital-Financial-Ecosystem/releases/tag/v1.0-p23.0.1): back up volumes before upgrading,
do not interrupt the first boot while `pg_upgrade` and migrations run.
