# Migration 008: Refresh bin/start scripts from image defaults

**Automated Script:** `/migrations/008_refresh_bin_start.sh`

---

## What This Migration Does

Overwrites `bin/start` for `core` and `horizon` on the volume with the current image defaults.

Changes (per service):
1. Backs up `/opt/stellar/<service>/bin/start` to `${MIGRATION_BACKUP_DIR}/<service>-bin-start.008.bak`
2. Copies `/opt/stellar-default/common/<service>/bin/start` over the volume copy
3. Restores the executable bit (`chmod +x`)

**Context:** Earlier images shipped `bin/start` without `export HOME=/var/lib/stellar`. On Ubuntu 24 + PG 16, libpq looks up `.pgpass` via `$HOME`, and supervisord starts programs with `HOME=/root` by default — the stellar UID cannot read `/root`, so `psql` in the readiness wait-loop prompts for a password and hangs forever. The fixed `bin/start` exports `HOME` before invoking `psql`.

`copy_defaults` in `/start` only copies files when the destination directory is empty, so upgraded volumes keep the old (broken) `bin/start`. This migration force-refreshes the file from `/opt/stellar-default/common/...`.

**New containers (organization-mainnet-v1.0-p23.0.1+)** ship with the fixed `bin/start` — no migration needed.

---

## Before You Start

**Requirements:**
- Container running
- Root or stellar user access
- ~1 minute

**Important:**
- No service restart is performed — the new `bin/start` only takes effect on the next supervisord program start
- Backups are written to `${MIGRATION_BACKUP_DIR}` (default `/opt/stellar/migration_backups`)

---

## Run the Migration

```bash
/migrations/008_refresh_bin_start.sh
```

**Expected output:**
```
[008] refreshed /opt/stellar/core/bin/start
[008] refreshed /opt/stellar/horizon/bin/start
```

---

## Verify

```bash
grep -n 'export HOME' /opt/stellar/core/bin/start /opt/stellar/horizon/bin/start
```

**You should see** `export HOME=/var/lib/stellar` near the top of each file.

Confirm the executable bit:
```bash
ls -l /opt/stellar/core/bin/start /opt/stellar/horizon/bin/start
```

Both should be `-rwxr-xr-x`.

The change takes effect on the next program start. Either restart the affected services:
```bash
supervisorctl restart stellar-core horizon
```
or wait for the next container restart.

---

## Rollback

```bash
cp /opt/stellar/migration_backups/core-bin-start.008.bak \
   /opt/stellar/core/bin/start
cp /opt/stellar/migration_backups/horizon-bin-start.008.bak \
   /opt/stellar/horizon/bin/start
chmod +x /opt/stellar/core/bin/start /opt/stellar/horizon/bin/start

supervisorctl restart stellar-core horizon
```

Rolling back reintroduces the `HOME=/root` hang on PG 16 — only do this if you are also reverting to a pre-v23 image.

---

## Manual Steps (if needed)

If you cannot run the script, edit each `bin/start` directly:

```bash
vi /opt/stellar/core/bin/start
vi /opt/stellar/horizon/bin/start
```

Add this line near the top of each file, before any `psql` invocation:

```bash
export HOME=/var/lib/stellar
```

Save, then:

```bash
chmod +x /opt/stellar/core/bin/start /opt/stellar/horizon/bin/start
supervisorctl restart stellar-core horizon
```

---

## FAQ

- **Safe to run multiple times?** Yes — the script just copies the same bytes again on a re-run.
- **Why force-overwrite instead of patch?** `bin/start` is part of the image contract and may carry other fixes; refreshing the whole file from `/opt/stellar-default/...` keeps the volume copy aligned with the image.
- **What if the readiness probe still hangs after the migration?** Check that `HOME` is now exported (`grep 'export HOME' /opt/stellar/horizon/bin/start`) and that `/var/lib/stellar/.pgpass` exists and is readable by the stellar user.
