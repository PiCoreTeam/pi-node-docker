# Migration 001: Enable Horizon Auto-Migrations

**Automated Script:** `/migrations/001_enable_horizon_auto_migrations.sh`

---

## What This Migration Does

Ensures `APPLY_MIGRATIONS=true` is present in the Horizon environment file (`/opt/stellar/horizon/etc/horizon.env`).

This is only needed for **previously existing containers** whose `horizon.env` was created before this setting was added to the default. New containers include it by default.

---

## Manual Steps

If you prefer to apply this manually:

```bash
# Check if already present
grep "APPLY_MIGRATIONS" /opt/stellar/horizon/etc/horizon.env

# If not present, add it
echo "export APPLY_MIGRATIONS=true" >> /opt/stellar/horizon/etc/horizon.env
```

---

## Using the Automated Script

```bash
/migrations/001_enable_horizon_auto_migrations.sh
```

The script is **idempotent** — safe to run multiple times.
