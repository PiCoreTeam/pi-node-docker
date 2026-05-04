# Ubuntu 24.04 + stellar-core 23 upgrade with PG 12 → 16 volume migration

**Date:** 2026-04-21
**Target branch:** `community-23` (sole community branch for stellar-core 23)
**Produced image:** `pinetwork/pi-node-docker:community-v1.1-p23.0.1`
**Source image under test:** `pinetwork/pi-node-docker:community-v1.0-p22.1`

## Goal

Upgrade the `community-23` image from Ubuntu 20.04 + PostgreSQL 12 to Ubuntu 24.04 + PostgreSQL 16, while keeping stellar-core 23.0.1 / horizon 23.0.0 / stellar-rpc 23.0.4. The resulting image must successfully mount a `/opt/stellar` directory produced by the older `community-v1.0-p22.1` image (Ubuntu 20.04 + PG 12 + stellar-core 22.1) and transparently migrate it to PG 16.

The upgrade is developed behind a reusable local testbed so the same "golden" PG 12 state can be re-used for many migration attempts without re-seeding.

## Stage 1 — Golden seed + clone flow (local testbed)

Scope: testnet2 only. mainnet/testnet can be added later by re-using the same scripts with a different `NETWORK` parameter.

### Layout

All paths relative to repo root:

```
internal/volumes/
  golden-testnet2-22.1/   # pristine seeded data from 22.1 image. Written once by seed.sh, never modified.
  work-testnet2/          # writable clone of the golden set; rebuilt every test run.
  seed.sh                 # produces golden-testnet2-22.1/ from pinetwork/pi-node-docker:community-v1.0-p22.1
  clone.sh                # rm -rf work-testnet2 && cp -a golden-testnet2-22.1/. work-testnet2/
  run.sh                  # docker run --rm <image-tag> --testnet2 with work-testnet2 bind-mounted at /opt/stellar
```

`internal/` is already gitignored at repo level; we additionally add an explicit `.gitignore` inside `internal/volumes/` keeping only the three `*.sh` scripts.

### `seed.sh` behavior

- Refuses to run if `golden-testnet2-22.1/` already exists and is non-empty. Pass `--force` to wipe and re-seed.
- Creates `golden-testnet2-22.1/` owned by current host user, then launches:

  ```
  docker run --rm --name pi-seed-testnet2-22.1 \
    -v $(pwd)/internal/volumes/golden-testnet2-22.1:/opt/stellar \
    -e POSTGRES_PASSWORD=postgres \
    pinetwork/pi-node-docker:community-v1.0-p22.1 --testnet2
  ```

- Polls for readiness from a second shell inside the container via `docker exec`:
  - `/opt/stellar/postgresql/data/PG_VERSION` contains `12`.
  - `/opt/stellar/core/buckets` has at least one `*.xdr.gz`.
  - `supervisorctl status` reports `core` and `horizon` both `RUNNING` for ≥ 60 s.
- On readiness, `docker stop pi-seed-testnet2-22.1` (default 10 s SIGTERM lets supervisord stop children cleanly).
- On timeout (default 30 min), abort and leave `golden-testnet2-22.1/` in place for inspection. Operator is expected to `--force` reseed.

### `clone.sh` behavior

- Rejects invocation if `work-testnet2/` is currently mounted by a running container (check `docker ps --filter volume=`).
- `rm -rf work-testnet2/` then `cp -a golden-testnet2-22.1/. work-testnet2/`.
- Does **not** attempt to normalize UIDs. If the consuming image has a different `stellar` UID than the 22.1 image, normalization happens during Stage 2 migration (see below).

### `run.sh` behavior

- `./run.sh <image-tag>` runs `docker run --rm -it -v $(pwd)/internal/volumes/work-testnet2:/opt/stellar -e POSTGRES_PASSWORD=postgres <image-tag> --testnet2`.
- Publishes ports `8000`, `8003`, `11626`, `31402` so horizon/rpc/core/quorum are reachable from the host. `5432` is deliberately not published.

## Stage 2 — Ubuntu 24.04 + PG 16 image on `community-23`

### File changes (all on `community-23`)

- `Dockerfile`: `FROM ubuntu:20.04` → `FROM ubuntu:24.04`. Pin the `stellar` user to a stable UID: `adduser --system --group --uid 999 --home /var/lib/stellar --disabled-password --shell /bin/bash stellar`.
- `dependencies`: install `postgresql-16` from Ubuntu 24.04 archive **and** `postgresql-12` from PGDG (`https://apt.postgresql.org/pub/repos/apt` noble-pgdg). PG 12 is needed only during migration; kept in the image for simplicity. Remove any Ubuntu 20.04-era package names that no longer exist on noble.
- `common/supervisor/etc/supervisord.conf`: `/usr/lib/postgresql/12/bin/postgres` → `/usr/lib/postgresql/16/bin/postgres`. Datadir path unchanged (`/opt/stellar/postgresql/data`).
- `start`: `PGBIN="/usr/lib/postgresql/12/bin"` → `PGBIN="/usr/lib/postgresql/16/bin"`. Add a new `maybe_upgrade_postgres` function, invoked from `main()` between `copy_defaults` and `init_db`. Migration must happen before any `start_postgres` call (init_db, init_stellar_core, init_horizon, and run_migrations all call it).
- `Makefile`: default `TAG?=community-v1.1-p23.0.1` (bump minor, base-OS change is a minor image-tag bump per repo convention).

### PG 12 → PG 16 upgrade logic

Implemented in `start` (not as a numbered `migrations/` script), because the existing migration framework requires postgres to already be running — fundamentally incompatible with a major-version upgrade. Heavy lifting goes in a dedicated helper at `common/postgresql/bin/upgrade-pg12-to-pg16.sh`, invoked by `maybe_upgrade_postgres`:

```
function maybe_upgrade_postgres() {
    [ -f $PGDATA/PG_VERSION ] || return 0             # fresh install
    local V=$(cat $PGDATA/PG_VERSION)
    case "$V" in
        16) echo "postgres: already at v16"; return 0 ;;
        12) /opt/stellar-default/common/postgresql/bin/upgrade-pg12-to-pg16.sh ;;
        *)  echo "postgres: unsupported version $V"; exit 1 ;;
    esac
}
```

`upgrade-pg12-to-pg16.sh` sequence:

1. Verify postgres is not running (`pg_isready -q` must fail). Abort if it is.
2. `mv $PGDATA $PGHOME/data.pg12.bak`.
3. `chown -R stellar:stellar $PGHOME/data.pg12.bak` — normalizes UID drift from the 22.1 image. One-time cost; only touches volume files.
4. `sudo -u stellar /usr/lib/postgresql/16/bin/initdb --locale=C.UTF-8 -D $PGDATA`.
5. Copy `pg_hba.conf` from `data.pg12.bak` to the new `$PGDATA`. Leave `postgresql.conf` at PG 16 defaults (old one will reference removed options); the repo's own `postgresql.conf` under `common/postgresql/etc/` is what `copy_defaults` installs to `$PGHOME/etc/` anyway — it's the one supervisord points to via `--config_file`, not the cluster's internal one.
6. `cd /tmp && sudo -u stellar /usr/lib/postgresql/16/bin/pg_upgrade --link -b /usr/lib/postgresql/12/bin -B /usr/lib/postgresql/16/bin -d $PGHOME/data.pg12.bak -D $PGDATA`.
7. Run the pg_upgrade-generated `analyze_new_cluster.sh`; log output; delete the script and `delete_old_cluster.sh`.
8. Leave `$PGHOME/data.pg12.bak` in place for rollback. README note: operator may `rm -rf` it after a successful smoke test.

Failure leaves `data.pg12.bak` intact and the new `$PGDATA` in whatever state pg_upgrade reached. Rollback: `rm -rf $PGDATA && mv $PGHOME/data.pg12.bak $PGDATA` and re-launch the 22.1 image.

Note: no new `migrations/005*.sh` file. The existing migration framework handles only post-PG-start changes (SQL, on-disk core config tweaks). PG major upgrade lives outside that framework by design.

### UID normalization

Old 22.1 image used `adduser --system` on Ubuntu 20.04 which typically picks UID 999. New image pins to 999 via `--uid 999`. If `seed.sh` produces data owned by a different UID, the migration's explicit `chown -R stellar:stellar` covers it. No changes to `clone.sh` are needed.

### Horizon / stellar-core / stellar-rpc migrations

No additional changes required. Horizon runs its own `db migrate up` on startup, which handles the horizon schema. stellar-core 22.1 → 23 on-disk state is compatible; the existing migrations `001`–`004` already cover captive-core config and `DEPRECATED_SQL_LEDGER_STATE`. stellar-rpc starts fresh if no state exists (migration `004` seeds its config).

## Smoke test protocol (manual, not automated)

After Stage 2 is merged and Stage 1 scripts are in place:

1. `./internal/volumes/seed.sh` — one-time, takes ~15–30 min for testnet2 to reach steady state.
2. `./internal/volumes/clone.sh` — seconds.
3. `make build` on `community-23` (produces `community-v1.1-p23.0.1`).
4. `./internal/volumes/run.sh pinetwork/pi-node-docker:community-v1.1-p23.0.1`.
5. Expected first-boot log lines: "postgres: detected v12, upgrading to v16", pg_upgrade output, then init_db logs "postgres: already initialized" because the quickstart marker persists.
6. Verify:
   - `docker exec <ctr> psql -U stellar -c 'SELECT version();'` → `PostgreSQL 16.x`.
   - `docker exec <ctr> supervisorctl status` → all services `RUNNING`.
   - `curl localhost:8000/` → horizon root with non-zero `history_latest_ledger`.
   - `curl localhost:11626/info` → core running, catching up or synced.
7. Re-run `clone.sh` + `run.sh` — second boot should log "postgres: already at v16" and come up clean.

## Out of scope

- Automated migration testing in CI. Manual smoke test only for now.
- Downgrade path PG 16 → PG 12. Operator uses the `data.pg12.bak` directory + old image if needed.
- Rolling the Ubuntu 24 upgrade into other branches (`organization-*`, `mainnet-relay`, etc.). Follow-up work, separate spec.
- mainnet/testnet golden seeds. `seed.sh` will be parameterizable for those later; not built now.
- Exporting golden data to a shared location (S3 / tarball). Local-only for now; add `export.sh` / `import.sh` only when a second machine needs the same seed.

## Success criteria

- `seed.sh` → `clone.sh` → `run.sh <new-image>` boots to all-RUNNING supervisord, with PG 16 serving data originally produced by PG 12, in a single container lifecycle.
- Second `clone.sh` → `run.sh` cycle no-ops `maybe_upgrade_postgres` and boots to the same end state.
- `community-23` still builds `community-v1.1-p23.0.1` via `make build` with no other workflow changes.
