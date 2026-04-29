#!/usr/bin/env bash
#
# Migration 007: refresh bin/start scripts on volume from image defaults.
#
# Earlier versions shipped bin/start without `export HOME=/var/lib/stellar`.
# On Ubuntu 24 + PG 16, libpq honors $HOME when looking for .pgpass; under
# supervisord HOME is inherited as /root, which stellar uid cannot read,
# so psql in the wait loop prompts for password and hangs forever.
#
# copy_defaults in /start only copies files when the destination directory
# is empty — upgraded volumes keep the old (broken) bin/start. This
# migration overwrites the file with the current image version.
#
# Idempotent: a re-run on an already-refreshed volume just copies the same
# bytes again.

set -euo pipefail

readonly DEFAULTS_DIR="/opt/stellar-default/common"
readonly STELLAR_HOME="/opt/stellar"
readonly BACKUP_DIR="${MIGRATION_BACKUP_DIR:-/opt/stellar/migration_backups}"

mkdir -p "$BACKUP_DIR"

for service in core horizon stellar-rpc; do
    src="${DEFAULTS_DIR}/${service}/bin/start"
    dst="${STELLAR_HOME}/${service}/bin/start"

    if [[ ! -f "$src" ]]; then
        echo "[007] no source for ${service} (${src}), skipping"
        continue
    fi
    if [[ ! -f "$dst" ]]; then
        echo "[007] no destination for ${service} (${dst}), skipping"
        continue
    fi

    cp "$dst" "${BACKUP_DIR}/${service}-bin-start.007.bak"
    cp "$src" "$dst"
    chmod +x "$dst"
    echo "[007] refreshed ${dst}"
done
