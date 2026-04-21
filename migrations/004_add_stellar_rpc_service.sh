#!/usr/bin/env bash
#
# Migration 004: add stellar-rpc service support to existing volumes.
#
# Fresh installs already get stellar-rpc wired up via copy_defaults and the
# baked-in supervisord.conf. Existing volumes from pre-23 releases ship an
# older supervisord.conf without a [program:stellar-rpc] block, so this
# migration appends it. Config directory population and placeholder
# substitution are handled by the normal start script flow (copy_defaults +
# init_stellar_rpc), which run before this migration.

set -e
set -u
set -o pipefail

readonly STELLAR_HOME="/opt/stellar"
readonly SUPERVISORD_CONF="${STELLAR_HOME}/supervisor/etc/supervisord.conf"
readonly PROGRAM_MARKER='[program:stellar-rpc]'

if [[ ! -f "${SUPERVISORD_CONF}" ]]; then
    echo "[004] supervisord.conf not found at ${SUPERVISORD_CONF}; skipping"
    exit 0
fi

if grep -Fq "${PROGRAM_MARKER}" "${SUPERVISORD_CONF}"; then
    echo "[004] supervisord.conf already contains ${PROGRAM_MARKER}; skipping"
    exit 0
fi

if [[ -n "${MIGRATION_BACKUP_DIR:-}" ]]; then
    cp "${SUPERVISORD_CONF}" "${MIGRATION_BACKUP_DIR}/supervisord.conf.bak"
    echo "[004] backed up supervisord.conf to ${MIGRATION_BACKUP_DIR}"
fi

cat >> "${SUPERVISORD_CONF}" <<'EOF'

[program:stellar-rpc]
user=stellar
directory=/opt/stellar/stellar-rpc
command=/opt/stellar/stellar-rpc/bin/start
autostart=false
startretries=50
autorestart=true
priority=40
redirect_stderr=true
EOF

echo "[004] appended ${PROGRAM_MARKER} to supervisord.conf"
