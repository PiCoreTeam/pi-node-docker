#!/usr/bin/env bash
#
# Migration 003: Fix validator3 port 31502→31402
#
# Changes:
#   - Fix ADDRESS port for validator3 in stellar-core.cfg (31502→31402)
#   - Fix ADDRESS port for validator3 in stellar-core-captive.yml (31502→31402)
#
# Context:
#   Nodes that already had migration 001 marked as executed may still carry
#   ADDRESS="34.64.252.77:31502" because migration 001 only targeted the
#   placeholder state (NAME="doesnotexistyet") and its sed ADDRESS pattern
#   was wrong. This migration is a targeted, idempotent port fix.
#
# Idempotent: Safe to run multiple times
#

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

CORE_CFG="/opt/stellar/core/etc/stellar-core.cfg"
CAPTIVE_CFG="/opt/stellar/horizon/etc/stellar-core-captive.yml"
BACKUP_DIR="${MIGRATION_BACKUP_DIR:-/opt/stellar/migration_backups}"

WRONG_ADDR='ADDRESS="34.64.252.77:31502"'
RIGHT_ADDR='ADDRESS="34.64.252.77:31402"'

# ==============================================================================
# Helpers
# ==============================================================================

log()   { echo "$(date '+%Y-%m-%d %H:%M:%S') [003] [INFO]  $*"; }
ok()    { echo "$(date '+%Y-%m-%d %H:%M:%S') [003] [OK]    $*"; }
error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [003] [ERROR] $*" >&2; }
die()   { error "$*"; exit 1; }

# ==============================================================================
# Main
# ==============================================================================

log "Starting migration: Fix validator3 port"

[[ -f "$CORE_CFG" ]] || die "Core config not found: $CORE_CFG"

# Check mainnet
if ! grep -qE 'NETWORK_PASSPHRASE\s*=\s*"Pi Network"' "$CORE_CFG"; then
    log "Not mainnet — skipping"
    ok "Migration skipped (not mainnet)"
    exit 0
fi

log "Running on mainnet (Pi Network)"

# Backup
mkdir -p "$BACKUP_DIR"
cp "$CORE_CFG" "$BACKUP_DIR/stellar-core.cfg.$(date +%Y%m%d_%H%M%S)"
log "Backup created: $BACKUP_DIR"

# ------------------------------------------------------------------------------
# Step 1: Fix port in stellar-core.cfg
# ------------------------------------------------------------------------------

if grep -qF "$WRONG_ADDR" "$CORE_CFG"; then
    log "Fixing validator3 port in stellar-core.cfg..."
    sed -i "s/ADDRESS=\"34\.64\.252\.77:31502\"/ADDRESS=\"34.64.252.77:31402\"/" "$CORE_CFG"
    ok "stellar-core.cfg fixed"
else
    log "stellar-core.cfg already has correct port (skipped)"
fi

# ------------------------------------------------------------------------------
# Step 2: Fix port in stellar-core-captive.yml (if exists)
# ------------------------------------------------------------------------------

if [[ -f "$CAPTIVE_CFG" ]]; then
    if grep -qF "$WRONG_ADDR" "$CAPTIVE_CFG"; then
        cp "$CAPTIVE_CFG" "$BACKUP_DIR/stellar-core-captive.yml.$(date +%Y%m%d_%H%M%S)"
        log "Fixing validator3 port in stellar-core-captive.yml..."
        sed -i "s/ADDRESS=\"34\.64\.252\.77:31502\"/ADDRESS=\"34.64.252.77:31402\"/" "$CAPTIVE_CFG"
        ok "stellar-core-captive.yml fixed"
    else
        log "stellar-core-captive.yml already has correct port (skipped)"
    fi
else
    log "stellar-core-captive.yml not present (skipped)"
fi

# ------------------------------------------------------------------------------
# Step 3: Restart services (only if supervisor is running)
# ------------------------------------------------------------------------------

if supervisorctl status &>/dev/null; then
    log "Supervisor is running, restarting stellar-core and horizon..."
    supervisorctl reread
    supervisorctl update
    supervisorctl restart stellar-core horizon || die "Failed to restart services"
    ok "Services restarted"
else
    log "Supervisor not running, skipping restart"
fi

# ------------------------------------------------------------------------------
# Verification
# ------------------------------------------------------------------------------

log "Verifying..."

if grep -qF "$WRONG_ADDR" "$CORE_CFG"; then
    die "Verification failed: stellar-core.cfg still has port 31502"
fi

if [[ -f "$CAPTIVE_CFG" ]] && grep -qF "$WRONG_ADDR" "$CAPTIVE_CFG"; then
    die "Verification failed: stellar-core-captive.yml still has port 31502"
fi

ok "Verification passed"
ok "Migration completed successfully"

