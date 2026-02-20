# Migration 002: Enable Captive Core for Horizon

**Automated Script:** `/migrations/002_captive_core_migration.sh`

---

## What This Migration Does

Migrates Horizon from standalone stellar-core ingestion to **Captive Core** mode.

> ⚠️ **Note:** This migration applies **only to mainnet** nodes. Other networks are skipped.

Changes:
1. Removes `STELLAR_CORE_DATABASE_URL` and `STELLAR_CORE_URL` from horizon.env
2. Sets `ENABLE_CAPTIVE_CORE_INGESTION="true"`
3. Updates `HISTORY_ARCHIVE_URLS` to include CDN fallback
4. Adds captive core env vars (binary path, storage path, config path, HTTP port)
5. Creates `stellar-core-captive.yml` config
6. Creates `captive-data` directory
7. Sets ownership of `captive-data` directory to `stellar:stellar`
8. Restarts Horizon (only if supervisorctl is available)

**New containers (v1.0-p19.9+)** already have captive core configured - no migration needed.

---

## Before You Start

✅ **Requirements:**
- Container running
- Root or stellar user access
- ~5 minutes of modifying configs
- ~few hours of reingestion (horizon will be available but not up to date during this time)

⚠️ **Important:**
- Horizon will restart automatically
- Backup is created at `/opt/stellar/migration_backups/`

---

## Run the Migration

```bash
/migrations/002_captive_core_migration.sh
```

**Expected output:**
```
YYYY-MM-DD HH:MM:SS [002] [INFO]  Starting migration: Enable Captive Core
YYYY-MM-DD HH:MM:SS [002] [INFO]  Running on mainnet (Pi Network)
YYYY-MM-DD HH:MM:SS [002] [INFO]  Backup created: /opt/stellar/migration_backups/horizon.env.YYYYMMDD_HHMMSS
YYYY-MM-DD HH:MM:SS [002] [OK]    STELLAR_CORE_DATABASE_URL removed
YYYY-MM-DD HH:MM:SS [002] [OK]    STELLAR_CORE_URL removed
YYYY-MM-DD HH:MM:SS [002] [OK]    ENABLE_CAPTIVE_CORE_INGESTION set to true
YYYY-MM-DD HH:MM:SS [002] [OK]    HISTORY_ARCHIVE_URLS updated with local + CDN fallback
YYYY-MM-DD HH:MM:SS [002] [OK]    STELLAR_CORE_BINARY_PATH added
...
YYYY-MM-DD HH:MM:SS [002] [OK]    Verification passed
YYYY-MM-DD HH:MM:SS [002] [OK]    Migration completed successfully
```

---

## Verify

Check captive core is running:
```bash
ps aux | grep stellar-core
```

✅ **You should see two stellar-core processes:**
- One with `--conf /opt/stellar/core/etc/stellar-core.cfg` (standalone)
- One with `--in-memory` (captive core)

Check Horizon status:
```bash
curl -s http://localhost:8000/ | jq '{history_latest_ledger, core_latest_ledger, ingest_latest_ledger}'
```

---

## Rollback

```bash
# Stop horizon
supervisorctl stop horizon

# Find backup
ls /opt/stellar/migration_backups/

# Restore (replace timestamp)
cp /opt/stellar/migration_backups/horizon.env.YYYYMMDD_HHMMSS \
   /opt/stellar/horizon/etc/horizon.env

# Restart
supervisorctl start horizon
```

---

## Manual Steps (if needed)

### 1. Edit horizon.env

```bash
vi /opt/stellar/horizon/etc/horizon.env
```

Remove these lines:
```bash
export STELLAR_CORE_DATABASE_URL="..."
export STELLAR_CORE_URL="..."
```

Change:
```bash
export ENABLE_CAPTIVE_CORE_INGESTION="false"
```
To:
```bash
export ENABLE_CAPTIVE_CORE_INGESTION="true"
```

Update:
```bash
export HISTORY_ARCHIVE_URLS="http://localhost:1570,https://history.mainnet.minepi.com"
```

Add:
```bash
export STELLAR_CORE_BINARY_PATH="/usr/bin/stellar-core"
export CAPTIVE_CORE_STORAGE_PATH="/opt/stellar/horizon/captive-data"
export CAPTIVE_CORE_CONFIG_PATH="/opt/stellar/horizon/etc/stellar-core-captive.yml"
export CAPTIVE_CORE_HTTP_PORT=11726 # its different from the default port 11626 to avoid conflicts
```

### 2. Create captive core config

```bash
cat > /opt/stellar/horizon/etc/stellar-core-captive.yml << 'EOF'
NETWORK_PASSPHRASE = "Pi Network"

[[VALIDATORS]]
NAME="validator1"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GDLA3KOMXKNHU5AGQB2R5VRBYCKM4X37NQVHTWRIQXNCOFOW4MZZSDTL"
ADDRESS="34.95.11.164:31402"
HISTORY="curl -sf https://history.mainnet.minepi.com/{0} -o {1}"

[[VALIDATORS]]
NAME="validator2"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GDGGD5XGBWLYS4XYJSUCX2CQ7ZS2JKIQTDOMPMPUU6LX74AINMRH2LMI"
ADDRESS="34.88.93.19:31402"
HISTORY="curl -sf https://history.mainnet.minepi.com/{0} -o {1}"

[[VALIDATORS]]
NAME="validator3"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GAXTE5AV5OCOEGJE4OPVMN5UJHAKDQCSVMXI4P7SZIGQXVO7LP4JKX4M"
ADDRESS="34.64.252.77:31502"
HISTORY="curl -sf https://history.mainnet.minepi.com/{0} -o {1}"
EOF
```

### 3. Create directory and restart

```bash
mkdir -p /opt/stellar/horizon/captive-data
chown stellar:stellar /opt/stellar/horizon/captive-data
supervisorctl restart horizon
```

---

## FAQ

- **Safe to run multiple times?** Yes, script is idempotent.
- **Downtime?** Brief restart of Horizon and reingestion. api will be available, but it will not be up to date (may take few hours).
- **Captive core not starting?** Check logs: `tail -f /var/log/supervisor/horizon-stdout*.log`
- **How to check captive core subprocess?** `curl http://localhost:11726/info`
- **How to monitor ingestion progress?** `grep "progress=" /var/log/supervisor/horizon-stdout*.log`
- **What's captive core?** Horizon spawns stellar-core as subprocess for ingestion instead of connecting to standalone instance.

