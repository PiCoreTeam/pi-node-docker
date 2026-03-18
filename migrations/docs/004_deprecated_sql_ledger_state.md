# Migration 004: Add DEPRECATED_SQL_LEDGER_STATE to stellar-core.cfg

**Automated Script:** `/migrations/004_deprecated_sql_ledger_state.sh`

---

## What This Migration Does

Adds `DEPRECATED_SQL_LEDGER_STATE=false` to `stellar-core.cfg`, required by stellar-core 21.x.

Changes:
1. Inserts `DEPRECATED_SQL_LEDGER_STATE=false` after the `DATABASE=` line in `stellar-core.cfg`

**Context:** stellar-core 21.x introduced the `DEPRECATED_SQL_LEDGER_STATE` setting and requires it to be explicitly set. Nodes upgrading from 20.x will fail to start without it.

**New containers (v1.1-p21.2+)** already include this setting — no migration needed.

---

## Before You Start

✅ **Requirements:**
- Container running
- Root or stellar user access
- ~1 minute

⚠️ **Important:**
- No service restart is performed — stellar-core must be restarted manually if it is already running
- Backup is created at `/opt/stellar/migration_backups/`

---

## Run the Migration

```bash
/migrations/004_deprecated_sql_ledger_state.sh
```

**Expected output:**
```
YYYY-MM-DD HH:MM:SS [004] [INFO]  Starting migration: Add DEPRECATED_SQL_LEDGER_STATE=false
YYYY-MM-DD HH:MM:SS [004] [INFO]  Backup created: /opt/stellar/migration_backups/stellar-core.cfg.YYYYMMDD_HHMMSS
YYYY-MM-DD HH:MM:SS [004] [OK]    DEPRECATED_SQL_LEDGER_STATE=false added after DATABASE line
YYYY-MM-DD HH:MM:SS [004] [OK]    Verification passed
YYYY-MM-DD HH:MM:SS [004] [OK]    Migration completed successfully
```

---

## Verify

```bash
grep 'DEPRECATED_SQL_LEDGER_STATE' /opt/stellar/core/etc/stellar-core.cfg
```

✅ **You should see:**
```
DEPRECATED_SQL_LEDGER_STATE=false
```

Then restart stellar-core to apply the change:
```bash
supervisorctl restart stellar-core
```

---

## Rollback

```bash
# Stop stellar-core
supervisorctl stop stellar-core

# Find backup
ls /opt/stellar/migration_backups/

# Restore (replace timestamp)
cp /opt/stellar/migration_backups/stellar-core.cfg.YYYYMMDD_HHMMSS \
   /opt/stellar/core/etc/stellar-core.cfg

# Restart
supervisorctl start stellar-core
```

---

## Manual Steps (if needed)

```bash
vi /opt/stellar/core/etc/stellar-core.cfg
```

Find the `DATABASE=` line and add the setting directly below it:

```toml
DEPRECATED_SQL_LEDGER_STATE=false
```

Then restart:
```bash
supervisorctl restart stellar-core
```

---

## FAQ

- **Safe to run multiple times?** Yes, script is idempotent — if the setting already exists, it is skipped.
- **Does this cause downtime?** The script itself does not restart services. You need to restart stellar-core manually for the change to take effect.
- **Why is this needed?** stellar-core 21.x dropped the legacy SQL ledger state feature and requires the flag to be explicitly disabled to confirm the operator is aware of the change.
- **What if stellar-core won't start?** Check logs: `tail -f /opt/stellar/core/stellar-core.log`
