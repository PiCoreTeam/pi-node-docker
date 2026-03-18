# Migration 003: Fix Validator3 Port

**Automated Script:** `/migrations/003_fix_validator3_port.sh`

---

## What This Migration Does

Fixes a wrong port for `validator3` in the stellar-core configuration files.

> ⚠️ **Note:** This migration applies **only to mainnet** nodes. Other networks are skipped.

Changes:
1. Fixes `ADDRESS` port for validator3 in `stellar-core.cfg` (`31502` → `31402`)
2. Fixes `ADDRESS` port for validator3 in `stellar-core-captive.yml` (`31502` → `31402`), if present
3. Restarts stellar-core and horizon (only if supervisorctl is available)

**Context:** Migration 001 only targeted nodes with a placeholder validator (`NAME="doesnotexistyet"`) and had a broken `sed` pattern for the ADDRESS line. As a result, some nodes that already had validator3 set up still carried the wrong port `31502`. This migration is a targeted, idempotent fix.

**New containers (v1.1+)** already ship with the correct port — no migration needed.

---

## Before You Start

✅ **Requirements:**
- Container running
- Root or stellar user access
- ~1 minute

⚠️ **Important:**
- stellar-core and horizon will restart briefly
- Backup is created at `/opt/stellar/migration_backups/`

---

## Run the Migration

```bash
/migrations/003_fix_validator3_port.sh
```

**Expected output:**
```
YYYY-MM-DD HH:MM:SS [003] [INFO]  Starting migration: Fix validator3 port
YYYY-MM-DD HH:MM:SS [003] [INFO]  Running on mainnet (Pi Network)
YYYY-MM-DD HH:MM:SS [003] [INFO]  Backup created: /opt/stellar/migration_backups
YYYY-MM-DD HH:MM:SS [003] [OK]    stellar-core.cfg fixed
YYYY-MM-DD HH:MM:SS [003] [OK]    stellar-core-captive.yml fixed
YYYY-MM-DD HH:MM:SS [003] [OK]    Services restarted
YYYY-MM-DD HH:MM:SS [003] [OK]    Verification passed
YYYY-MM-DD HH:MM:SS [003] [OK]    Migration completed successfully
```

---

## Verify

Check validator3 has the correct port in stellar-core.cfg:
```bash
grep -A3 'NAME="validator3"' /opt/stellar/core/etc/stellar-core.cfg
```

✅ **You should see** `ADDRESS="34.64.252.77:31402"` (port `31402`, not `31502`).

Check captive core config (if present):
```bash
grep -A3 'NAME="validator3"' /opt/stellar/horizon/etc/stellar-core-captive.yml
```

Check services are running:
```bash
supervisorctl status
```

---

## Rollback

```bash
# Stop services
supervisorctl stop stellar-core horizon

# Find backup
ls /opt/stellar/migration_backups/

# Restore (replace timestamp)
cp /opt/stellar/migration_backups/stellar-core.cfg.YYYYMMDD_HHMMSS \
   /opt/stellar/core/etc/stellar-core.cfg

# Restart
supervisorctl restart stellar-core horizon
```

---

## Manual Steps (if needed)

### 1. Edit stellar-core.cfg

```bash
vi /opt/stellar/core/etc/stellar-core.cfg
```

Find the validator3 section and fix the port:

```toml
# Change this:
ADDRESS="34.64.252.77:31502"

# To this:
ADDRESS="34.64.252.77:31402"
```

### 2. Edit stellar-core-captive.yml (if present)

```bash
vi /opt/stellar/horizon/etc/stellar-core-captive.yml
```

Apply the same port fix for validator3.

### 3. Restart services

```bash
supervisorctl restart stellar-core horizon
```

---

## FAQ

- **Safe to run multiple times?** Yes, script is idempotent — already-correct ports are skipped.
- **Downtime?** Brief restart of stellar-core and horizon (a few seconds).
- **How do I know if I need this?** Run `grep 'validator3' -A3 /opt/stellar/core/etc/stellar-core.cfg` and check if the port is `31502`.
- **What if stellar-core won't start after restart?** Check logs: `tail -f /opt/stellar/core/stellar-core.log`
