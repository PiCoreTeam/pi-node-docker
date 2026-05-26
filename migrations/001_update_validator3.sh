#!/usr/bin/env bash
#
# Migration 001: Update validator3 configuration
#
# Changes:
#   - Replace "doesnotexistyet" placeholder with validator3
#   - Add validator3 to PREFERRED_PEER_KEYS
#   - Update HISTORY URLs to use CDN
#   - Run Horizon database migration
#
# Idempotent: Safe to run multiple times
#

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

CFG="/opt/stellar/core/etc/stellar-core.cfg"
BACKUP_DIR="${MIGRATION_BACKUP_DIR:-/opt/stellar/migration_backups}"

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

log "Starting migration: Update validator3"

# Check config exists
[[ -f "$CFG" ]] || die "Config file not found: $CFG"

# Check if running on mainnet (handle both with and without spaces around =)
IS_MAINNET=false
if grep -qE 'NETWORK_PASSPHRASE\s*=\s*"Pi Network"' "$CFG"; then
    IS_MAINNET=true
    log "Running on mainnet (Pi Network)"
else
    log "Not running on mainnet - skipping stellar-core config changes"
fi

# ==============================================================================
# Mainnet-only changes (stellar-core config)
# ==============================================================================

if [[ "$IS_MAINNET" == "true" ]]; then
    # Create backup
    mkdir -p "$BACKUP_DIR"
    BACKUP="$BACKUP_DIR/stellar-core.cfg.$(date +%Y%m%d_%H%M%S)"
    cp "$CFG" "$BACKUP"
    log "Backup created: $BACKUP"

    # --------------------------------------------------------------------------
    # Step 1: Update validator3 section
    # --------------------------------------------------------------------------

    if grep -qF 'NAME="doesnotexistyet"' "$CFG"; then
        log "Updating validator3 section (placeholder state)..."
        sed -i \
            -e 's/NAME="doesnotexistyet"/NAME="validator3"/' \
            -e 's/PUBLIC_KEY="GDKG2ZYQHSALQCXYQXAWVTT5IRFCDU2R5Q2TSH4GIJC6W2XZ5L3IG2OV"/PUBLIC_KEY="GAXTE5AV5OCOEGJE4OPVMN5UJHAKDQCSVMXI4P7SZIGQXVO7LP4JKX4M"/' \
            -e 's/ADDRESS="127\.0\.0\.1:31502"/ADDRESS="34.64.252.77:31402"/' \
            -e 's|HISTORY="curl -sf http://127\.0\.0\.1:31503/|HISTORY="curl -sf https://history.mainnet.minepi.com/|' \
            "$CFG"
        ok "Validator3 section updated from placeholder state"
    else
        log "Validator3 placeholder not present (skipped)"
    fi

    # Fix validator3 port 31502→31402 for nodes already past the placeholder state
    if grep -qF 'ADDRESS="34.64.252.77:31502"' "$CFG"; then
        log "Fixing validator3 port 31502→31402..."
        sed -i 's/ADDRESS="34\.64\.252\.77:31502"/ADDRESS="34.64.252.77:31402"/' "$CFG"
        ok "Validator3 port fixed"
    else
        log "Validator3 port already correct (skipped)"
    fi

    # --------------------------------------------------------------------------
    # Step 2: Add validator3 to PREFERRED_PEER_KEYS
    # --------------------------------------------------------------------------

    if ! grep -qF '"$validator3"' "$CFG"; then
        log "Adding validator3 to PREFERRED_PEER_KEYS..."
        sed -i 's/\(\$validator2",\)$/\1\n    "\$validator3"/' "$CFG"
        ok "Validator3 added to PREFERRED_PEER_KEYS"
    else
        log "Validator3 already in PREFERRED_PEER_KEYS (skipped)"
    fi

    # --------------------------------------------------------------------------
    # Step 3: Update HISTORY URLs to CDN
    # --------------------------------------------------------------------------

    if grep -qF 'http://34.95.11.164:31403/' "$CFG"; then
        log "Updating validator1 HISTORY to CDN..."
        sed -i 's|http://34\.95\.11\.164:31403/|https://history.mainnet.minepi.com/|g' "$CFG"
        ok "Validator1 HISTORY updated"
    else
        log "Validator1 HISTORY already uses CDN (skipped)"
    fi

    if grep -qF 'http://34.88.93.19:31403/' "$CFG"; then
        log "Updating validator2 HISTORY to CDN..."
        sed -i 's|http://34\.88\.93\.19:31403/|https://history.mainnet.minepi.com/|g' "$CFG"
        ok "Validator2 HISTORY updated"
    else
        log "Validator2 HISTORY already uses CDN (skipped)"
    fi
fi

# ------------------------------------------------------------------------------
# Step 4: Run Horizon database migration
# ------------------------------------------------------------------------------

log "Running Horizon database migration..."
if /opt/stellar/horizon/bin/horizon db migrate up; then
    ok "Horizon migration completed"
else
    die "Horizon migration failed"
fi

# ------------------------------------------------------------------------------
# Step 5: Restart services (only if supervisor is running)
# ------------------------------------------------------------------------------

# Restart services only if supervisor is running AND we made mainnet changes
if [[ "$IS_MAINNET" == "true" ]] && supervisorctl status &>/dev/null; then
    log "Supervisor is running, restarting services..."
    supervisorctl reread
    supervisorctl update
    supervisorctl restart stellar-core horizon || die "Failed to restart services"
    ok "Services restarted"
else
    log "Supervisor not running or no config changes, skipping restart"
fi

# ------------------------------------------------------------------------------
# Verification (mainnet only)
# ------------------------------------------------------------------------------

if [[ "$IS_MAINNET" == "true" ]]; then
    log "Verifying mainnet config changes..."

    if ! grep -qF 'NAME="validator3"' "$CFG"; then
        die "Verification failed: validator3 NAME not found"
    fi

    if ! grep -qF '"$validator3"' "$CFG"; then
        die "Verification failed: validator3 not in PREFERRED_PEER_KEYS"
    fi

    if grep -qF 'ADDRESS="34.64.252.77:31502"' "$CFG"; then
        die "Verification failed: validator3 still has wrong port 31502"
    fi

    ok "Mainnet config verification passed"
fi

ok "Migration completed successfully"

