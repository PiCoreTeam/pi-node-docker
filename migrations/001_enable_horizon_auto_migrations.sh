#!/usr/bin/env bash
#
# Migration 001: Enable Horizon auto-migrations
#
# Changes:
#   - Ensures APPLY_MIGRATIONS=true is present in horizon.env
#
# Purpose:
#   For previously existing containers whose horizon.env does not yet
#   include APPLY_MIGRATIONS=true. New containers get it by default.
#
# Idempotent: Safe to run multiple times
#

set -euo pipefail

HORIZON_ENV="/opt/stellar/horizon/etc/horizon.env"

# ==============================================================================
# Helpers
# ==============================================================================

log()   { echo "$(date '+%Y-%m-%d %H:%M:%S') [001] [INFO]  $*"; }
ok()    { echo "$(date '+%Y-%m-%d %H:%M:%S') [001] [OK]    $*"; }
error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [001] [ERROR] $*" >&2; }
die()   { error "$*"; exit 1; }

# ==============================================================================
# Main
# ==============================================================================

log "Starting migration: Enable Horizon auto-migrations"

[[ -f "$HORIZON_ENV" ]] || die "Horizon env file not found: $HORIZON_ENV"

if grep -q "^export APPLY_MIGRATIONS=true" "$HORIZON_ENV"; then
    ok "APPLY_MIGRATIONS=true already present (skipped)"
else
    log "Adding APPLY_MIGRATIONS=true to $HORIZON_ENV"
    echo "export APPLY_MIGRATIONS=true" >> "$HORIZON_ENV"
    ok "APPLY_MIGRATIONS=true added to horizon.env"
fi

ok "Migration completed successfully"
