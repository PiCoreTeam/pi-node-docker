#!/usr/bin/env bash
#
# Migration 003: Remove deprecated settings from stellar-core.cfg
#
# Changes:
#   - Removes DEPRECATED_SQL_LEDGER_STATE=false from stellar-core.cfg
#     (setting was required by stellar-core 21.x but is no longer required in 23.x)
#   - Removes KNOWN_CURSORS from stellar-core.cfg
#     (no longer required in 23.x)
#
# Supported environments: mainnet, testnet, testnet2
# Idempotent: Safe to run multiple times
#

set -euo pipefail

CORE_CFG="/opt/stellar/core/etc/stellar-core.cfg"
BACKUP_DIR="${MIGRATION_BACKUP_DIR:-/opt/stellar/migration_backups}"

log()   { echo "$(date '+%Y-%m-%d %H:%M:%S') [003] [INFO]  $*"; }
ok()    { echo "$(date '+%Y-%m-%d %H:%M:%S') [003] [OK]    $*"; }
error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [003] [ERROR] $*" >&2; }
die()   { error "$*"; exit 1; }

log "Starting migration: Remove deprecated settings"

[[ -f "$CORE_CFG" ]] || die "Core config file not found: $CORE_CFG"

# ==============================================================================
# Backup
# ==============================================================================
mkdir -p "$BACKUP_DIR"
BACKUP="$BACKUP_DIR/stellar-core.cfg.$(date +%Y%m%d_%H%M%S)"
cp "$CORE_CFG" "$BACKUP"
log "Backup created: $BACKUP"

# ==============================================================================
# Step 1: Remove DEPRECATED_SQL_LEDGER_STATE line
# ==============================================================================
if grep -qE "^DEPRECATED_SQL_LEDGER_STATE" "$CORE_CFG"; then
    sed -i '/^DEPRECATED_SQL_LEDGER_STATE/d' "$CORE_CFG"
    ok "DEPRECATED_SQL_LEDGER_STATE removed"
else
    log "DEPRECATED_SQL_LEDGER_STATE not present (skipped)"
fi

# ==============================================================================
# Step 2: Remove KNOWN_CURSORS line
# ==============================================================================
if grep -qE "^KNOWN_CURSORS" "$CORE_CFG"; then
    sed -i '/^KNOWN_CURSORS/d' "$CORE_CFG"
    ok "KNOWN_CURSORS removed"
else
    log "KNOWN_CURSORS not present (skipped)"
fi

# ==============================================================================
# Verification
# ==============================================================================
log "Verifying migration..."
! grep -qE "^DEPRECATED_SQL_LEDGER_STATE" "$CORE_CFG" || die "DEPRECATED_SQL_LEDGER_STATE still present in $CORE_CFG"
! grep -qE "^KNOWN_CURSORS" "$CORE_CFG" || die "KNOWN_CURSORS still present in $CORE_CFG"

ok "Verification passed"
ok "Migration completed successfully"
