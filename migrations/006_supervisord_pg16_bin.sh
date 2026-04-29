#!/usr/bin/env bash
#
# Migration 005: point supervisord's postgresql program at the PG 16 binary.
#
# Volumes produced by v1.0-p22.1 (Ubuntu 20.04 + PG 12) carry an older
# supervisord.conf whose [program:postgresql] command runs the PG 12 binary.
# copy_defaults skips re-copying when $SUPHOME/etc exists, so the path isn't
# updated automatically. This migration rewrites the line to the PG 16 path.
#
# The PG 12 → PG 16 cluster upgrade itself is done earlier in /start by
# maybe_upgrade_postgres + upgrade-pg12-to-pg16.sh; this migration only
# corrects the supervisord service definition so supervisord launches the
# matching binary.

set -e
set -u
set -o pipefail

readonly STELLAR_HOME="/opt/stellar"
readonly SUPERVISORD_CONF="${STELLAR_HOME}/supervisor/etc/supervisord.conf"
readonly OLD_BIN="/usr/lib/postgresql/12/bin/postgres"
readonly NEW_BIN="/usr/lib/postgresql/16/bin/postgres"

if [[ ! -f "${SUPERVISORD_CONF}" ]]; then
    echo "[005] supervisord.conf not found at ${SUPERVISORD_CONF}; skipping"
    exit 0
fi

if ! grep -Fq "${OLD_BIN}" "${SUPERVISORD_CONF}"; then
    echo "[005] supervisord.conf already on PG 16 (or unknown layout); skipping"
    exit 0
fi

if [[ -n "${MIGRATION_BACKUP_DIR:-}" ]]; then
    cp "${SUPERVISORD_CONF}" "${MIGRATION_BACKUP_DIR}/supervisord.conf.005.bak"
    echo "[005] backed up supervisord.conf to ${MIGRATION_BACKUP_DIR}/supervisord.conf.005.bak"
fi

sed -i "s|${OLD_BIN}|${NEW_BIN}|g" "${SUPERVISORD_CONF}"
echo "[005] rewrote supervisord postgresql command from PG 12 → PG 16 binary"
