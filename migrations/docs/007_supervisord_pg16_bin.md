# Migration 007: Point supervisord at the PG 16 postgres binary

**Automated Script:** `/migrations/007_supervisord_pg16_bin.sh`

---

## What This Migration Does

Rewrites the `[program:postgresql]` command in `supervisord.conf` from the PG 12 binary path to the PG 16 binary path.

Changes:
1. Replaces every occurrence of `/usr/lib/postgresql/12/bin/postgres` with `/usr/lib/postgresql/16/bin/postgres` in `/opt/stellar/supervisor/etc/supervisord.conf`

**Context:** Volumes created from `v1.0-p22.1` (Ubuntu 20.04 + PG 12) carry an older `supervisord.conf` whose postgresql program command runs the PG 12 binary. The image's `copy_defaults` step skips re-copying when `$SUPHOME/etc` already exists, so the path is not updated automatically when the container moves to v23 (PG 16). Without this migration, supervisord would try to launch the missing PG 12 binary even after `pg_upgrade` has migrated the cluster.

The PG 12 → PG 16 cluster upgrade itself happens earlier in `/start` via `maybe_upgrade_postgres` — this migration only corrects the supervisord service definition so supervisord launches the matching binary.

**New containers (organization-mainnet-v1.0-p23.0.1+)** ship with `supervisord.conf` already pointing at PG 16 — no migration needed.

---

## Before You Start

**Requirements:**
- Container running
- Root or stellar user access
- ~1 minute

**Important:**
- No service restart is performed — supervisord must be reloaded for the change to take effect
- Backup is created at `${MIGRATION_BACKUP_DIR}/supervisord.conf.005.bak` when the migration runner provides that variable

---

## Run the Migration

```bash
/migrations/007_supervisord_pg16_bin.sh
```

**Expected output:**
```
[005] backed up supervisord.conf to /opt/stellar/migration_backups/supervisord.conf.005.bak
[005] rewrote supervisord postgresql command from PG 12 → PG 16 binary
```

If the file is already on PG 16:
```
[005] supervisord.conf already on PG 16 (or unknown layout); skipping
```

> Note: log lines are tagged `[005]` and the backup file is named `supervisord.conf.005.bak` because the script reuses an earlier internal tag — this is cosmetic and does not affect behavior.

---

## Verify

```bash
grep '^command=' /opt/stellar/supervisor/etc/supervisord.conf | grep postgres
```

**You should see** the command pointing at `/usr/lib/postgresql/16/bin/postgres`, not `/usr/lib/postgresql/12/bin/postgres`.

Then reload supervisord so it picks up the new command:

```bash
supervisorctl reread
supervisorctl update
```

---

## Rollback

Only meaningful if you are also reverting the cluster to PG 12 (which requires restoring `data.pg12.bak` — see migration 008 / the v23 release notes).

```bash
cp /opt/stellar/migration_backups/supervisord.conf.005.bak \
   /opt/stellar/supervisor/etc/supervisord.conf

supervisorctl reread
supervisorctl update
```

---

## Manual Steps (if needed)

```bash
vi /opt/stellar/supervisor/etc/supervisord.conf
```

Find the `[program:postgresql]` section and change:

```ini
command=/usr/lib/postgresql/12/bin/postgres ...
```

to:

```ini
command=/usr/lib/postgresql/16/bin/postgres ...
```

Then reload supervisord:

```bash
supervisorctl reread
supervisorctl update
```

---
