# Migration 003: Add DEPRECATED_SQL_LEDGER_STATE=false

**Automated Script:** `/migrations/003_deprecated_sql_ledger_state.sh`

---

## What This Migration Does

Adds `DEPRECATED_SQL_LEDGER_STATE=false` to the stellar-core configuration file (`/opt/stellar/core/etc/stellar-core.cfg`).

This setting is **required by stellar-core 21.x** and disables the deprecated SQL-based ledger state storage. Without it, stellar-core 21.x will fail to start.

This is only needed for **previously existing containers** whose `stellar-core.cfg` was created before this setting was added to the default. New containers include it by default.

---

## Manual Steps

If you prefer to apply this manually:

```bash
# Check if already present
grep "DEPRECATED_SQL_LEDGER_STATE" /opt/stellar/core/etc/stellar-core.cfg

# If not present, add it after the DATABASE line
sed -i '/^DATABASE=/a DEPRECATED_SQL_LEDGER_STATE=false' /opt/stellar/core/etc/stellar-core.cfg
```

---

## Using the Automated Script

```bash
/migrations/003_deprecated_sql_ledger_state.sh
```

The script is **idempotent** — safe to run multiple times.

---

## Rollback

```bash
# Find backup
ls /opt/stellar/migration_backups/

# Restore (replace timestamp)
cp /opt/stellar/migration_backups/stellar-core.cfg.YYYYMMDD_HHMMSS \
   /opt/stellar/core/etc/stellar-core.cfg
```
