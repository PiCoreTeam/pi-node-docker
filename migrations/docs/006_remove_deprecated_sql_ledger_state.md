# Migration 006: Remove deprecated stellar-core settings

**Automated Script:** `/migrations/006_remove_deprecated_sql_ledger_state.sh`

---

## What This Migration Does

Removes settings from `stellar-core.cfg` that are rejected by stellar-core v23.

Changes:
1. Removes the `DEPRECATED_SQL_LEDGER_STATE` line (added by migration 004 for v21, no longer accepted in v23)
2. Removes the `KNOWN_CURSORS` line (no longer accepted in v23)

**Context:** stellar-core v23 fails on startup if either setting is present. This migration is required for any volume created before the v23 upgrade. Both lines are removed unconditionally — they are not replaced with new values.

**New containers (organization-mainnet-v1.0-p23.0.1+)** ship without these settings — no migration needed.

---

## Before You Start

**Requirements:**
- Container running
- Root or stellar user access
- ~1 minute

**Important:**
- No service restart is performed — stellar-core must be restarted manually if it is already running
- Backup is created at `/opt/stellar/migration_backups/`

---

## Run the Migration

```bash
/migrations/006_remove_deprecated_sql_ledger_state.sh
```

**Expected output:**
```
YYYY-MM-DD HH:MM:SS [003] [INFO]  Starting migration: Remove deprecated settings
YYYY-MM-DD HH:MM:SS [003] [INFO]  Backup created: /opt/stellar/migration_backups/stellar-core.cfg.YYYYMMDD_HHMMSS
YYYY-MM-DD HH:MM:SS [003] [OK]    DEPRECATED_SQL_LEDGER_STATE removed
YYYY-MM-DD HH:MM:SS [003] [OK]    KNOWN_CURSORS removed
YYYY-MM-DD HH:MM:SS [003] [OK]    Verification passed
YYYY-MM-DD HH:MM:SS [003] [OK]    Migration completed successfully
```

> Note: log lines are tagged `[003]` because the script reuses an earlier internal tag — this is cosmetic and does not affect behavior.

---

## Verify

```bash
grep -E '^(DEPRECATED_SQL_LEDGER_STATE|KNOWN_CURSORS)' /opt/stellar/core/etc/stellar-core.cfg
```

**You should see:** no output (both lines absent).

Then restart stellar-core to apply the change:
```bash
supervisorctl restart stellar-core
```

---

## Rollback

Rolling back is only meaningful if you also downgrade stellar-core to v22 — v23 will not start with these lines present.

```bash
supervisorctl stop stellar-core

ls /opt/stellar/migration_backups/

cp /opt/stellar/migration_backups/stellar-core.cfg.YYYYMMDD_HHMMSS \
   /opt/stellar/core/etc/stellar-core.cfg

supervisorctl start stellar-core
```

---

## Manual Steps (if needed)

```bash
vi /opt/stellar/core/etc/stellar-core.cfg
```

Delete any lines beginning with `DEPRECATED_SQL_LEDGER_STATE` or `KNOWN_CURSORS`, then restart:

```bash
supervisorctl restart stellar-core
```

---

## FAQ

- **Safe to run multiple times?** Yes, script is idempotent — already-removed lines are skipped.
- **Does this cause downtime?** The script itself does not restart services. You need to restart stellar-core manually for the change to take effect.
- **Why is this needed?** stellar-core v23 rejects these settings on startup — `DEPRECATED_SQL_LEDGER_STATE` was a v21 transitional flag, and `KNOWN_CURSORS` was removed entirely.
- **What if stellar-core won't start?** Check logs: `tail -f /opt/stellar/core/stellar-core.log`
