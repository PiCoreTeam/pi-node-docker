# Ubuntu 24 + stellar-core 23 Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On `community-23`, upgrade base image to Ubuntu 24.04 + PostgreSQL 16 (while keeping stellar-core 23.0.1 / horizon 23.0.0 / stellar-rpc 23.0.4), and ship a local testbed that mounts data from the prior `community-v1.0-p22.1` image and migrates PG 12 → 16 on first boot.

**Architecture:** Stage 1 is bind-mount based testbed scripts under `internal/volumes/` — `seed.sh` produces a pristine "golden" data set once from the 22.1 image, `clone.sh` makes a fresh `cp -a` copy per test run, `run.sh` boots any target image against the clone. Stage 2 modifies `community-23` to build on `ubuntu:24.04`, installs both PG 12 (from PGDG, for pg_upgrade) and PG 16, pins the stellar UID to 999, and adds `maybe_upgrade_postgres` in `start` (calling `common/postgresql/bin/upgrade-pg12-to-pg16.sh`) that runs `pg_upgrade --link` before any postgres daemon starts.

**Tech Stack:** bash, Docker (linux/amd64), Ubuntu 24.04, PostgreSQL 16 + 12, supervisord, stellar-core 23.0.1, horizon 23.0.0, stellar-rpc 23.0.4.

---

## File Structure

**Stage 1 — testbed (Create):**
- `internal/volumes/.gitignore` — track only `*.sh` + `.gitignore`; ignore all data.
- `internal/volumes/seed.sh` — one-time producer of `golden-testnet2-22.1/`.
- `internal/volumes/clone.sh` — fast `cp -a` of golden → `work-testnet2/`.
- `internal/volumes/run.sh` — run target image against `work-testnet2/`.

**Stage 2 — image (Create):**
- `common/postgresql/bin/upgrade-pg12-to-pg16.sh` — pg_upgrade helper invoked by `start`.

**Stage 2 — image (Modify):**
- `Dockerfile` — base image + pinned UID.
- `dependencies` — PG 16 + PG 12 (PGDG) + Ubuntu 24-compatible runtime libs.
- `common/supervisor/etc/supervisord.conf` — postgres 16 bin path.
- `start` — `PGBIN` → 16, add `maybe_upgrade_postgres`, wire into `main`.
- `Makefile` — default `TAG` bump to `community-v1.1-p23.0.1`.

---

## Task 1: Create `internal/volumes/` gitignore

**Files:**
- Create: `internal/volumes/.gitignore`

- [ ] **Step 1: Write `.gitignore`**

```
*
!.gitignore
!*.sh
```

- [ ] **Step 2: Verify it only tracks scripts + itself**

Run: `git check-ignore -v internal/volumes/golden-testnet2-22.1/foo internal/volumes/seed.sh internal/volumes/.gitignore 2>&1 || true`

Expected output shows `golden-testnet2-22.1/foo` is ignored, and `seed.sh` / `.gitignore` are NOT ignored.

- [ ] **Step 3: Commit**

```bash
git add internal/volumes/.gitignore
git commit -m "chore: gitignore data under internal/volumes, keep scripts"
```

---

## Task 2: Write `seed.sh`

**Files:**
- Create: `internal/volumes/seed.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Produce a pristine testnet2 data set from pinetwork/pi-node-docker:community-v1.0-p22.1.
# Writes to internal/volumes/golden-testnet2-22.1/. One-time; re-run with --force to reseed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN="$HERE/golden-testnet2-22.1"
IMAGE="pinetwork/pi-node-docker:community-v1.0-p22.1"
NAME="pi-seed-testnet2-22.1"
TIMEOUT_SEC="${TIMEOUT_SEC:-1800}"   # 30 min default
STABLE_SEC="${STABLE_SEC:-60}"       # required consecutive RUNNING duration
FORCE=0

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        *) echo "usage: $0 [--force]" >&2; exit 2 ;;
    esac
done

if [ -d "$GOLDEN" ] && [ -n "$(ls -A "$GOLDEN" 2>/dev/null || true)" ]; then
    if [ "$FORCE" -ne 1 ]; then
        echo "error: $GOLDEN exists and is non-empty; pass --force to reseed" >&2
        exit 1
    fi
    echo "--force given; wiping $GOLDEN"
    rm -rf "$GOLDEN"
fi
mkdir -p "$GOLDEN"

cleanup() {
    docker rm -f "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "seed: pulling $IMAGE"
docker pull --platform linux/amd64 "$IMAGE"

echo "seed: starting container $NAME"
docker run -d --rm --platform linux/amd64 --name "$NAME" \
    -v "$GOLDEN:/opt/stellar" \
    -e POSTGRES_PASSWORD=postgres \
    "$IMAGE" --testnet2 >/dev/null

started=$(date +%s)
stable_since=0

while true; do
    now=$(date +%s)
    if [ $((now - started)) -gt "$TIMEOUT_SEC" ]; then
        echo "seed: timed out after ${TIMEOUT_SEC}s waiting for readiness" >&2
        docker logs --tail 200 "$NAME" >&2 || true
        exit 1
    fi

    if ! docker ps --format '{{.Names}}' | grep -q "^${NAME}$"; then
        echo "seed: container exited prematurely" >&2
        docker logs --tail 200 "$NAME" >&2 || true
        exit 1
    fi

    pgver=$(docker exec "$NAME" sh -c 'cat /opt/stellar/postgresql/data/PG_VERSION 2>/dev/null || true' | tr -d '[:space:]')
    buckets=$(docker exec "$NAME" sh -c 'ls /opt/stellar/core/buckets/*.xdr.gz 2>/dev/null | head -n 1 || true')
    status=$(docker exec "$NAME" supervisorctl status 2>/dev/null || true)
    core_run=$(echo "$status"   | awk '/^stellar-core/    {print $2}')
    horizon_run=$(echo "$status" | awk '/^horizon/        {print $2}')

    if [ "$pgver" = "12" ] && [ -n "$buckets" ] && [ "$core_run" = "RUNNING" ] && [ "$horizon_run" = "RUNNING" ]; then
        if [ "$stable_since" -eq 0 ]; then
            stable_since=$now
            echo "seed: both services RUNNING, waiting ${STABLE_SEC}s for stability..."
        elif [ $((now - stable_since)) -ge "$STABLE_SEC" ]; then
            break
        fi
    else
        stable_since=0
    fi

    sleep 5
done

echo "seed: readiness reached, stopping container gracefully"
docker stop "$NAME" >/dev/null
echo "seed: done. Golden data at $GOLDEN"
```

- [ ] **Step 2: Make executable + syntax check**

Run: `chmod +x internal/volumes/seed.sh && bash -n internal/volumes/seed.sh`

Expected: no output (parse OK).

- [ ] **Step 3: Commit**

```bash
git add internal/volumes/seed.sh
git commit -m "feat: add seed.sh to produce golden testnet2 data from 22.1 image"
```

---

## Task 3: Write `clone.sh`

**Files:**
- Create: `internal/volumes/clone.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Rebuild internal/volumes/work-testnet2/ as a fresh cp -a clone of golden-testnet2-22.1/.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN="$HERE/golden-testnet2-22.1"
WORK="$HERE/work-testnet2"

if [ ! -d "$GOLDEN" ] || [ -z "$(ls -A "$GOLDEN" 2>/dev/null || true)" ]; then
    echo "error: $GOLDEN is missing or empty; run seed.sh first" >&2
    exit 1
fi

# Refuse if any container is currently using $WORK as a bind source.
if [ -d "$WORK" ]; then
    if docker ps --format '{{.ID}} {{.Mounts}}' | grep -q "$WORK"; then
        echo "error: $WORK is currently bind-mounted by a running container; stop it first" >&2
        exit 1
    fi
    echo "clone: removing existing $WORK"
    rm -rf "$WORK"
fi

mkdir -p "$WORK"
echo "clone: copying golden → work (cp -a)"
cp -a "$GOLDEN/." "$WORK/"
echo "clone: done. Work data at $WORK"
```

- [ ] **Step 2: Make executable + syntax check**

Run: `chmod +x internal/volumes/clone.sh && bash -n internal/volumes/clone.sh`

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add internal/volumes/clone.sh
git commit -m "feat: add clone.sh to produce fresh work copy of golden data"
```

---

## Task 4: Write `run.sh`

**Files:**
- Create: `internal/volumes/run.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Run a pi-node-docker image against internal/volumes/work-testnet2/ bind-mounted at /opt/stellar.
# Usage: run.sh <image-tag>   e.g. run.sh pinetwork/pi-node-docker:community-v1.1-p23.0.1
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$HERE/work-testnet2"

if [ $# -ne 1 ]; then
    echo "usage: $0 <image-tag>" >&2
    exit 2
fi
IMAGE="$1"

if [ ! -d "$WORK" ] || [ -z "$(ls -A "$WORK" 2>/dev/null || true)" ]; then
    echo "error: $WORK is missing or empty; run clone.sh first" >&2
    exit 1
fi

exec docker run --rm -it --platform linux/amd64 \
    --name pi-work-testnet2 \
    -v "$WORK:/opt/stellar" \
    -e POSTGRES_PASSWORD=postgres \
    -p 8000:8000 \
    -p 8003:8003 \
    -p 11626:11626 \
    -p 31402:31402 \
    "$IMAGE" --testnet2
```

- [ ] **Step 2: Make executable + syntax check**

Run: `chmod +x internal/volumes/run.sh && bash -n internal/volumes/run.sh`

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add internal/volumes/run.sh
git commit -m "feat: add run.sh to boot a pi-node-docker image against work volume"
```

---

## Task 5: Produce the golden data set

**Files:** none modified; this task *runs* the seed script. Time cost ~15–30 min; may be run in the background.

- [ ] **Step 1: Confirm the 22.1 image is pullable**

Run: `docker manifest inspect pinetwork/pi-node-docker:community-v1.0-p22.1 >/dev/null && echo ok`

Expected: `ok`.

- [ ] **Step 2: Seed**

Run: `./internal/volumes/seed.sh`

Expected final line: `seed: done. Golden data at .../internal/volumes/golden-testnet2-22.1`

- [ ] **Step 3: Sanity-check the golden data**

Run: `cat internal/volumes/golden-testnet2-22.1/postgresql/data/PG_VERSION && ls internal/volumes/golden-testnet2-22.1/core/buckets | head`

Expected: `12` and a listing of `.xdr.gz` files.

- [ ] **Step 4: Verify clone works**

Run: `./internal/volumes/clone.sh && cat internal/volumes/work-testnet2/postgresql/data/PG_VERSION`

Expected: `12`.

- [ ] **Step 5: (no commit)**

Data is gitignored; nothing to commit. Proceed to Stage 2.

---

## Task 6: Bump base image + pin stellar UID in `Dockerfile`

**Files:**
- Modify: `Dockerfile` (line 9 and line 26)

- [ ] **Step 1: Change base image**

Change line 9 from:
```
FROM ubuntu:20.04
```
to:
```
FROM ubuntu:24.04
```

- [ ] **Step 2: Pin stellar UID**

Change line 26 from:
```
RUN adduser --system --group --quiet --home /var/lib/stellar --disabled-password --shell /bin/bash stellar
```
to:
```
RUN adduser --system --group --quiet --uid 999 --home /var/lib/stellar --disabled-password --shell /bin/bash stellar
```

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "build: base on ubuntu:24.04 and pin stellar UID to 999"
```

---

## Task 7: Update `dependencies` for Ubuntu 24 + PGDG PG 12

**Files:**
- Modify: `dependencies` (full rewrite of package list)

- [ ] **Step 1: Rewrite the file**

Replace full contents with:

```bash
#! /usr/bin/env bash
set -e

# dependencies (Ubuntu 24.04 noble)
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl wget git gnupg ca-certificates apt-transport-https lsb-release

# PGDG repo (for PG 12 pg_upgrade). PG 16 ships in Ubuntu 24.04 main.
install -d /usr/share/keyrings
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /usr/share/keyrings/pgdg.gpg
echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] https://apt.postgresql.org/pub/repos/apt noble-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list
apt-get update

apt-get install -y libpq-dev libsqlite3-dev libsasl2-dev \
                   postgresql-client-16 postgresql-16 postgresql-contrib-16 \
                   postgresql-12 \
                   sudo vim zlib1g-dev supervisor psmisc \
                   rsync jq netcat-openbsd \
                   libunwind8 sqlite3 libc++abi1 libc++1  # stellar-core runtime deps

apt-get clean
rm -rf /var/lib/apt/lists/*

echo "\nDone installing dependencies...\n"
```

Notes for the engineer:
- On noble, `libc++abi1-12` and `libc++1-12` no longer exist; `libc++abi1` and `libc++1` (noble's meta-packages) replace them. `stellar-core` links against libc++ at build time and only needs the shared libs present.
- `postgresql-12` from PGDG is installed *for the pg_upgrade binaries only*; supervisord points at the PG 16 binaries (Task 8).
- `gnupg` + `ca-certificates` are new relative to the 20.04 version; they are required to trust the PGDG signing key.

- [ ] **Step 2: Commit**

```bash
git add dependencies
git commit -m "build: install postgresql-16 and postgresql-12 (PGDG) on ubuntu 24.04"
```

---

## Task 8: Point supervisord at PG 16 binary

**Files:**
- Modify: `common/supervisor/etc/supervisord.conf` (line 19)

- [ ] **Step 1: Change the postgres command**

Change line 19 from:
```
command=/usr/lib/postgresql/12/bin/postgres -D "/opt/stellar/postgresql/data" -c config_file=/opt/stellar/postgresql/etc/postgresql.conf
```
to:
```
command=/usr/lib/postgresql/16/bin/postgres -D "/opt/stellar/postgresql/data" -c config_file=/opt/stellar/postgresql/etc/postgresql.conf
```

- [ ] **Step 2: Commit**

```bash
git add common/supervisor/etc/supervisord.conf
git commit -m "build: run supervisord-managed postgres from PG 16 binary"
```

---

## Task 9: Create the pg_upgrade helper script

**Files:**
- Create: `common/postgresql/bin/upgrade-pg12-to-pg16.sh`

- [ ] **Step 1: Create the directory and script**

Run: `mkdir -p common/postgresql/bin`

Then create `common/postgresql/bin/upgrade-pg12-to-pg16.sh` with contents:

```bash
#!/usr/bin/env bash
# One-shot PG 12 → PG 16 cluster upgrade using pg_upgrade --link.
# Invoked by `maybe_upgrade_postgres` in /start when PG_VERSION == 12.
# Preconditions: no postgres daemon running; $PGDATA is a valid PG 12 data dir.
set -euo pipefail

PGHOME="${PGHOME:-/opt/stellar/postgresql}"
PGDATA="${PGDATA:-$PGHOME/data}"
OLD_BIN="/usr/lib/postgresql/12/bin"
NEW_BIN="/usr/lib/postgresql/16/bin"
BAK="$PGHOME/data.pg12.bak"

echo "postgres: detected v12, upgrading to v16"

if "$OLD_BIN/pg_isready" -q 2>/dev/null; then
    echo "upgrade-pg: postgres is still running — aborting" >&2
    exit 1
fi

if [ -d "$BAK" ]; then
    echo "upgrade-pg: $BAK already exists — previous run left partial state; aborting" >&2
    exit 1
fi

mv "$PGDATA" "$BAK"
chown -R stellar:stellar "$BAK"

# Fresh PG 16 cluster.
sudo -u stellar "$NEW_BIN/initdb" --locale=C.UTF-8 -D "$PGDATA"

# Keep old pg_hba.conf so auth rules survive the upgrade. postgresql.conf is
# left at PG 16 defaults (the runtime config supervisord uses lives elsewhere
# at $PGHOME/etc/postgresql.conf and is unchanged).
install -o stellar -g stellar -m 0600 "$BAK/pg_hba.conf" "$PGDATA/pg_hba.conf"

# pg_upgrade must be invoked from a writable cwd owned by the running user.
UPG_DIR="$(mktemp -d -t pg_upgrade.XXXXXX)"
chown stellar:stellar "$UPG_DIR"
pushd "$UPG_DIR" >/dev/null

sudo -u stellar "$NEW_BIN/pg_upgrade" --link \
    -b "$OLD_BIN" -B "$NEW_BIN" \
    -d "$BAK" -D "$PGDATA"

# pg_upgrade emits analyze_new_cluster.sh + delete_old_cluster.sh in cwd.
if [ -x ./analyze_new_cluster.sh ]; then
    sudo -u stellar ./analyze_new_cluster.sh || true
fi
rm -f ./analyze_new_cluster.sh ./delete_old_cluster.sh ./*.log 2>/dev/null || true

popd >/dev/null
rm -rf "$UPG_DIR"

echo "postgres: pg_upgrade complete; v12 data preserved at $BAK"
```

- [ ] **Step 2: Make executable + syntax check**

Run: `chmod +x common/postgresql/bin/upgrade-pg12-to-pg16.sh && bash -n common/postgresql/bin/upgrade-pg12-to-pg16.sh`

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add common/postgresql/bin/upgrade-pg12-to-pg16.sh
git commit -m "feat: add pg_upgrade helper for PG 12 → 16 cluster migration"
```

---

## Task 10: Wire `maybe_upgrade_postgres` into `start`

**Files:**
- Modify: `start` (line 11, `main()` body, and append new function)

- [ ] **Step 1: Bump `PGBIN` to PG 16**

Change line 11 from:
```
export PGBIN="/usr/lib/postgresql/12/bin"
```
to:
```
export PGBIN="/usr/lib/postgresql/16/bin"
```

- [ ] **Step 2: Call `maybe_upgrade_postgres` from `main`**

In `main()` (around line 31), insert the call between `copy_defaults` and `init_db`. Change:

```bash
	copy_defaults
	init_db
```

to:

```bash
	copy_defaults
	maybe_upgrade_postgres
	init_db
```

- [ ] **Step 3: Add the function definition**

Append the following function to `start` immediately before the `pushd () {` definition (around line 393):

```bash
function maybe_upgrade_postgres() {
	# Major-version PG upgrade must run BEFORE any start_postgres call;
	# PG 16 binaries cannot attach to a PG 12 data directory.
	if [ ! -f "$PGDATA/PG_VERSION" ]; then
		return 0
	fi
	local V
	V=$(cat "$PGDATA/PG_VERSION" | tr -d '[:space:]')
	case "$V" in
		16) echo "postgres: already at v16"; return 0 ;;
		12) /opt/stellar-default/common/postgresql/bin/upgrade-pg12-to-pg16.sh ;;
		*)  echo "postgres: unsupported cluster version '$V'" >&2; exit 1 ;;
	esac
}
```

- [ ] **Step 4: Syntax check**

Run: `bash -n start`

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add start
git commit -m "feat: upgrade PG 12 clusters to PG 16 on first boot"
```

---

## Task 11: Bump default image tag in `Makefile`

**Files:**
- Modify: `Makefile` (line 3)

- [ ] **Step 1: Update the default tag**

Change line 3 from:
```
TAG?=community-v1.0-p23.0.1
```
to:
```
TAG?=community-v1.1-p23.0.1
```

- [ ] **Step 2: Commit**

```bash
git add Makefile
git commit -m "build: bump default TAG to community-v1.1-p23.0.1"
```

---

## Task 12: Build the new image

**Files:** none modified; this task *runs* the build. Time cost ~30–60 min (stellar-core build from source).

- [ ] **Step 1: Build**

Run: `make build`

Expected final line: `Successfully tagged pinetwork/pi-node-docker:community-v1.1-p23.0.1` (or equivalent).

- [ ] **Step 2: Smoke-check the resulting image metadata**

Run:
```bash
docker run --rm --entrypoint /bin/sh pinetwork/pi-node-docker:community-v1.1-p23.0.1 \
    -c 'cat /etc/os-release | head -2; ls /usr/lib/postgresql/; id stellar'
```

Expected:
- `VERSION_ID="24.04"`
- `12  16` (both PG versions installed)
- `uid=999 gid=999` for `stellar`.

- [ ] **Step 3: (no commit)** — image artifact is local.

---

## Task 13: End-to-end smoke test

**Files:** none modified; runs the full Stage 1 flow against the new image.

- [ ] **Step 1: Re-clone to a fresh PG 12 state**

Run: `./internal/volumes/clone.sh`

Expected: `clone: done. Work data at .../internal/volumes/work-testnet2`.

- [ ] **Step 2: Boot the new image in one terminal**

Run in terminal A: `./internal/volumes/run.sh pinetwork/pi-node-docker:community-v1.1-p23.0.1`

Expected early log lines include: `postgres: detected v12, upgrading to v16`, `pg_upgrade complete`, then supervisord starting postgres/stellar-core/horizon.

- [ ] **Step 3: Verify from a second terminal**

Run in terminal B:
```bash
docker exec pi-work-testnet2 sudo -u postgres /usr/lib/postgresql/16/bin/psql -c 'SELECT version();'
docker exec pi-work-testnet2 supervisorctl status
curl -fsS localhost:8000/ | jq '{core_latest_ledger, history_latest_ledger}'
curl -fsS localhost:11626/info | jq '.info.state'
```

Expected:
- `psql` reports `PostgreSQL 16.x`.
- `supervisorctl status` shows `postgresql`, `stellar-core`, `horizon`, `rpc` states (`rpc` may be stopped depending on autostart defaults — that's fine).
- `horizon` returns non-zero ledger numbers.
- `stellar-core` state is `Synced!` or `Catching up`.

- [ ] **Step 4: Second-boot idempotency**

Stop the container from terminal A (Ctrl-C; `docker stop pi-work-testnet2` if still running). The `work-testnet2/` directory now holds PG 16 data (migration 005 already ran). *Without* re-cloning, run in terminal A:

```
./internal/volumes/run.sh pinetwork/pi-node-docker:community-v1.1-p23.0.1
```

Expected early log lines include: `postgres: already at v16`. Supervisord comes up again cleanly. `psql` from terminal B still reports `PostgreSQL 16.x`.

- [ ] **Step 5: (no commit)** — verification only.

---

## Task 14: Update README usage note

**Files:**
- Modify: `README.md` (append short section)

- [ ] **Step 1: Append a section**

Append the following to `README.md`:

```markdown
## Upgrading from `community-v1.0-p22.1` (PG 12) to `community-v1.1-p23.0.1` (PG 16)

The new image detects a PG 12 cluster at `/opt/stellar/postgresql/data` on first
boot and runs `pg_upgrade --link` automatically. The old cluster is preserved at
`/opt/stellar/postgresql/data.pg12.bak` and may be removed after verification.

Rollback: stop the container, `rm -rf /opt/stellar/postgresql/data` and
`mv /opt/stellar/postgresql/data.pg12.bak /opt/stellar/postgresql/data`, then
run the old `community-v1.0-p22.1` image.

For local migration testing against a seeded PG 12 data set, see
`internal/volumes/` (not shipped; scripts in-repo).
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: note PG 12 → 16 auto-upgrade and rollback"
```

---

## Done

After Task 14 the branch is ready for review. Merge criteria:

1. Tasks 12 and 13 pass (image builds; smoke test shows PG 16 serving data originally produced by PG 12, with idempotent re-boot).
2. Spec's success criteria (see `docs/superpowers/specs/2026-04-21-ubuntu24-sc23-migration-design.md`) all hold.
