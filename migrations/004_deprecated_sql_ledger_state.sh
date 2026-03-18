#!/usr/bin/env bash
#
# Migration 004: Add DEPRECATED_SQL_LEDGER_STATE=false to stellar-core.cfg
#
# Changes:
#   - Adds DEPRECATED_SQL_LEDGER_STATE=false to stellar-core.cfg
#     if not already present (required by stellar-core 21.x)
#
# Supported environments: mainnet
# Idempotent: Safe to run multiple times
#

set -euo pipefail

CORE_CFG="/opt/stellar/core/etc/stellar-core.cfg"
BACKUP_DIR="${MIGRATION_BACKUP_DIR:-/opt/stellar/migration_backups}"

log()   { echo "$(date '+%Y-%m-%d %H:%M:%S') [004] [INFO]  $*"; }
ok()    { echo "$(date '+%Y-%m-%d %H:%M:%S') [004] [OK]    $*"; }
error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [004] [ERROR] $*" >&2; }
die()   { error "$*"; exit 1; }

log "Starting migration: Add DEPRECATED_SQL_LEDGER_STATE=false"

[[ -f "$CORE_CFG" ]] || die "Core config file not found: $CORE_CFG"

# ==============================================================================
# Backup
# ==============================================================================
mkdir -p "$BACKUP_DIR"
BACKUP="$BACKUP_DIR/stellar-core.cfg.$(date +%Y%m%d_%H%M%S)"
cp "$CORE_CFG" "$BACKUP"
log "Backup created: $BACKUP"

# ==============================================================================
# Step 1: Add DEPRECATED_SQL_LEDGER_STATE=false after the DATABASE line
# ==============================================================================
if grep -q "^DEPRECATED_SQL_LEDGER_STATE=" "$CORE_CFG"; then
    log "DEPRECATED_SQL_LEDGER_STATE already present (skipped)"
else
    sed -i '/^DATABASE=/a DEPRECATED_SQL_LEDGER_STATE=false' "$CORE_CFG"
    ok "DEPRECATED_SQL_LEDGER_STATE=false added after DATABASE line"
fi

# ==============================================================================
# Verification
# ==============================================================================
log "Verifying migration..."
grep -q "^DEPRECATED_SQL_LEDGER_STATE=" "$CORE_CFG" || die "DEPRECATED_SQL_LEDGER_STATE not found in $CORE_CFG"

ok "Verification passed"
ok "Migration completed successfully"

