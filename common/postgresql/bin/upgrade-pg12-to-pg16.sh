#!/usr/bin/env bash
# One-shot PG 12 → PG 16 cluster upgrade using pg_upgrade --link.
# Invoked by `maybe_upgrade_postgres` in /start when PG_VERSION == 12.
# Preconditions: no postgres daemon running; $PGDATA is a valid PG 12 data dir.
# Runs all PG operations as the `postgres` OS user (matching init_db and
# supervisord's program:postgresql), so the upgraded cluster is readable by
# the service the container will launch.
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
chown -R postgres:postgres "$BAK"

# Fresh PG 16 cluster.
sudo -u postgres "$NEW_BIN/initdb" --locale=C.UTF-8 -D "$PGDATA"

# Keep old pg_hba.conf so auth rules survive the upgrade. postgresql.conf is
# left at PG 16 defaults (the runtime config supervisord uses lives elsewhere
# at $PGHOME/etc/postgresql.conf and is unchanged).
install -o postgres -g postgres -m 0600 "$BAK/pg_hba.conf" "$PGDATA/pg_hba.conf"

# pg_upgrade must be invoked from a writable cwd owned by the running user.
UPG_DIR="$(mktemp -d -t pg_upgrade.XXXXXX)"
chown postgres:postgres "$UPG_DIR"
pushd "$UPG_DIR" >/dev/null

sudo -u postgres "$NEW_BIN/pg_upgrade" --link \
    -b "$OLD_BIN" -B "$NEW_BIN" \
    -d "$BAK" -D "$PGDATA"

# pg_upgrade emits analyze_new_cluster.sh + delete_old_cluster.sh in cwd.
if [ -x ./analyze_new_cluster.sh ]; then
    sudo -u postgres ./analyze_new_cluster.sh || true
fi
rm -f ./analyze_new_cluster.sh ./delete_old_cluster.sh ./*.log 2>/dev/null || true

popd >/dev/null
rm -rf "$UPG_DIR"

echo "postgres: pg_upgrade complete; v12 data preserved at $BAK"
