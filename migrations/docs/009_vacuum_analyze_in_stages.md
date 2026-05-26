# Migration 009: Refresh planner statistics with `vacuumdb --analyze-in-stages`

**Automated Script:** `/migrations/009_vacuum_analyze_in_stages.sh`

---

## What This Migration Does

Runs the following as the `postgres` user, against the running cluster:

```bash
vacuumdb --all --analyze-in-stages -j 4
```

Effect:

1. Iterates over every database in the cluster (`core`, `horizon`, `postgres`, `template1`, …).
2. Runs `ANALYZE` in **three progressively-deeper stages**:
   - **Stage 1** — minimal stats, written quickly so queries stop running blind.
   - **Stage 2** — default statistics target.
   - **Stage 3** — maximum statistics target.
3. Parallelizes work across **4 jobs** (`-j 4`).

**Context.** `pg_upgrade` does **not** carry `pg_statistic` across a major-version upgrade. A freshly-upgraded PG 16 cluster starts with empty planner statistics; until `ANALYZE` has run, the query planner makes poor join/scan decisions and queries on `horizon` (large tables) can be orders of magnitude slower than expected.

`common/postgresql/bin/upgrade-pg12-to-pg16.sh` already invokes `pg_upgrade`'s emitted `analyze_new_cluster.sh`, but with `|| true` — any failure there is silently swallowed and the cluster ends up un-analyzed. This migration is the defensive follow-up: re-runs the stats refresh explicitly, with parallelism, on every container where it has not yet succeeded.

**Re-running is safe.** On a healthy cluster this just refreshes statistics — cheap and harmless. On a freshly-upgraded cluster it is essential.

---

## Before You Start

**Requirements:**
- Container running with PostgreSQL 16 reachable (`pg_isready` returns 0).
- The migration is invoked by `/start` after `init_db` brings up Postgres, so the precondition holds during normal container start.

**Important:**
- `--analyze-in-stages` makes three full passes; on a large `horizon` database the migration can take from a few minutes (small node) to **tens of minutes** (large archival node). Stage 1 finishes first so query performance improves quickly even if the later stages are still running.
- The migration acquires only `SHARE UPDATE EXCLUSIVE` locks per table (same as autovacuum) — it does **not** block reads or writes.
- No service restart is required.

---

## Run the Migration

Auto-executed at container start via `migration_runner.sh`. To run manually:

```bash
/migrations/009_vacuum_analyze_in_stages.sh
```

**Expected output:**

```
[009] running vacuumdb --all --analyze-in-stages -j 4 ...
vacuumdb: vacuuming database "core"
vacuumdb: vacuuming database "horizon"
vacuumdb: vacuuming database "postgres"
vacuumdb: vacuuming database "template1"
[009] vacuumdb completed
```

If Postgres is not running, the migration skips with:

```
[009] postgres is not running; skipping (run vacuumdb manually later)
```

In that case, re-run by hand once Postgres is up (see **Manual Steps** below).

---

## Verify

After completion, confirm statistics exist for the largest tables in `horizon`:

```bash
sudo -u postgres psql -d horizon -c "
  SELECT relname, n_live_tup, last_analyze, last_autoanalyze
  FROM pg_stat_user_tables
  ORDER BY n_live_tup DESC
  LIMIT 10;
"
```

**You should see** a recent timestamp in `last_analyze` for the top tables, and non-null `n_live_tup`.

A second sanity check — `pg_statistic` should be populated:

```bash
sudo -u postgres psql -d horizon -c "
  SELECT count(*) FROM pg_statistic;
"
```

Anything well above zero is normal; **zero** on a populated database means the analyze did not run.

---

## Rollback

There is no rollback. Statistics are derived data; you cannot meaningfully "un-analyze". If a future ANALYZE produced bad plans (extremely rare) you would re-run `vacuumdb --analyze --all` to refresh them again.

---

## Manual Steps (if needed)

If the automated migration was skipped (Postgres not running) or you want to run it on a node that already executed the migration:

```bash
# Confirm Postgres is up
pg_isready

# Run the same command the migration runs
sudo -u postgres vacuumdb --all --analyze-in-stages -j 4
```

To target only one database (e.g. `horizon` is the slow one):

```bash
sudo -u postgres vacuumdb --analyze-in-stages -j 4 horizon
```

To run just the fast first stage if you need queries responsive immediately and will let autovacuum finish the rest:

```bash
sudo -u postgres vacuumdb --analyze-only --analyze-in-stages --stage 1 --all -j 4
```

---

## FAQ

- **Safe to run multiple times?** Yes — re-running just refreshes statistics. No data is modified.
- **Does it block stellar-core or horizon?** No. `ANALYZE` takes a `SHARE UPDATE EXCLUSIVE` lock per table, which is compatible with normal reads/writes and with autovacuum.
- **Why not just rely on `analyze_new_cluster.sh` from `pg_upgrade`?** It is invoked with `|| true` in `upgrade-pg12-to-pg16.sh`, so a transient failure leaves the cluster silently un-analyzed. This migration is the explicit, idempotent backstop.
- **Why isn't this needed on fresh containers (no upgrade)?** Autovacuum populates statistics over time as data is written. The acute problem is only the post-`pg_upgrade` moment when the cluster has data but zero stats — but running this migration on a steady-state cluster is still a harmless refresh.
- **What if `vacuumdb` fails partway through?** The migration runner exits with the script's non-zero status and marks the migration as **not** executed, so the next container start retries. Partial work already done is not lost — statistics that were written stay written.
