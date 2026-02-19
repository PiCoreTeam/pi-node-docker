#!/usr/bin/env bash
#
# Migration 002: Enable Captive Core for Horizon
#
# Changes:
#   - Remove STELLAR_CORE_DATABASE_URL from horizon.env
#   - Remove STELLAR_CORE_URL from horizon.env
#   - Set ENABLE_CAPTIVE_CORE_INGESTION to true
#   - Update HISTORY_ARCHIVE_URLS to include CDN fallback
#   - Add STELLAR_CORE_BINARY_PATH
#   - Add CAPTIVE_CORE_STORAGE_PATH
#   - Add CAPTIVE_CORE_CONFIG_PATH
#   - Add CAPTIVE_CORE_HTTP_PORT
#   - Create stellar-core-captive.yml config file
#   - Create captive-data directory
#
# Idempotent: Safe to run multiple times
#

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

HORIZON_ENV="/opt/stellar/horizon/etc/horizon.env"
CAPTIVE_CONFIG="/opt/stellar/horizon/etc/stellar-core-captive.yml"
CAPTIVE_DATA_DIR="/opt/stellar/horizon/captive-data"
CORE_CFG="/opt/stellar/core/etc/stellar-core.cfg"
BACKUP_DIR="${MIGRATION_BACKUP_DIR:-/opt/stellar/migration_backups}"

# ==============================================================================
# Helpers
# ==============================================================================

log()   { echo "$(date '+%Y-%m-%d %H:%M:%S') [002] [INFO]  $*"; }
ok()    { echo "$(date '+%Y-%m-%d %H:%M:%S') [002] [OK]    $*"; }
error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [002] [ERROR] $*" >&2; }
die()   { error "$*"; exit 1; }

# ==============================================================================
# Main
# ==============================================================================

log "Starting migration: Enable Captive Core"

# Check config exists
[[ -f "$HORIZON_ENV" ]] || die "Horizon env file not found: $HORIZON_ENV"
[[ -f "$CORE_CFG" ]] || die "Core config file not found: $CORE_CFG"

# Check if running on mainnet
IS_MAINNET=false
if grep -qE 'NETWORK_PASSPHRASE\s*=\s*"Pi Network"' "$CORE_CFG"; then
    IS_MAINNET=true
    log "Running on mainnet (Pi Network)"
else
    log "Not running on mainnet - skipping captive core migration"
    ok "Migration skipped (not mainnet)"
    exit 0
fi

# ==============================================================================
# Mainnet-only changes
# ==============================================================================

# Create backup
mkdir -p "$BACKUP_DIR"
BACKUP="$BACKUP_DIR/horizon.env.$(date +%Y%m%d_%H%M%S)"
cp "$HORIZON_ENV" "$BACKUP"
log "Backup created: $BACKUP"

# ------------------------------------------------------------------------------
# Step 1: Remove STELLAR_CORE_DATABASE_URL
# ------------------------------------------------------------------------------

if grep -q '^export STELLAR_CORE_DATABASE_URL=' "$HORIZON_ENV"; then
    log "Removing STELLAR_CORE_DATABASE_URL..."
    sed -i '/^export STELLAR_CORE_DATABASE_URL=/d' "$HORIZON_ENV"
    ok "STELLAR_CORE_DATABASE_URL removed"
else
    log "STELLAR_CORE_DATABASE_URL already removed (skipped)"
fi

# ------------------------------------------------------------------------------
# Step 2: Remove STELLAR_CORE_URL
# ------------------------------------------------------------------------------

if grep -q '^export STELLAR_CORE_URL=' "$HORIZON_ENV"; then
    log "Removing STELLAR_CORE_URL..."
    sed -i '/^export STELLAR_CORE_URL=/d' "$HORIZON_ENV"
    ok "STELLAR_CORE_URL removed"
else
    log "STELLAR_CORE_URL already removed (skipped)"
fi

# ------------------------------------------------------------------------------
# Step 3: Set ENABLE_CAPTIVE_CORE_INGESTION to true
# ------------------------------------------------------------------------------

if grep -q 'ENABLE_CAPTIVE_CORE_INGESTION="true"' "$HORIZON_ENV"; then
    log "ENABLE_CAPTIVE_CORE_INGESTION already true (skipped)"
elif grep -q 'ENABLE_CAPTIVE_CORE_INGESTION="false"' "$HORIZON_ENV"; then
    log "Enabling captive core ingestion..."
    sed -i 's/ENABLE_CAPTIVE_CORE_INGESTION="false"/ENABLE_CAPTIVE_CORE_INGESTION="true"/' "$HORIZON_ENV"
    ok "ENABLE_CAPTIVE_CORE_INGESTION set to true"
else
    log "Adding ENABLE_CAPTIVE_CORE_INGESTION..."
    echo 'export ENABLE_CAPTIVE_CORE_INGESTION="true"' >> "$HORIZON_ENV"
    ok "ENABLE_CAPTIVE_CORE_INGESTION added and set to true"
fi

# ------------------------------------------------------------------------------
# Step 4: Update HISTORY_ARCHIVE_URLS to include CDN fallback
# ------------------------------------------------------------------------------

HISTORY_URLS="http://localhost:1570,https://history.mainnet.minepi.com"
if grep -q "HISTORY_ARCHIVE_URLS=\"$HISTORY_URLS\"" "$HORIZON_ENV"; then
    log "HISTORY_ARCHIVE_URLS already has CDN fallback (skipped)"
elif grep -q '^export HISTORY_ARCHIVE_URLS=' "$HORIZON_ENV"; then
    log "Updating HISTORY_ARCHIVE_URLS to include CDN fallback..."
    sed -i "s|^export HISTORY_ARCHIVE_URLS=.*|export HISTORY_ARCHIVE_URLS=\"$HISTORY_URLS\"|" "$HORIZON_ENV"
    ok "HISTORY_ARCHIVE_URLS updated with local + CDN fallback"
else
    log "Adding HISTORY_ARCHIVE_URLS..."
    echo "export HISTORY_ARCHIVE_URLS=\"$HISTORY_URLS\"" >> "$HORIZON_ENV"
    ok "HISTORY_ARCHIVE_URLS added"
fi

# ------------------------------------------------------------------------------
# Step 5: Add new captive core environment variables
# ------------------------------------------------------------------------------

if ! grep -q '^export STELLAR_CORE_BINARY_PATH=' "$HORIZON_ENV"; then
    log "Adding STELLAR_CORE_BINARY_PATH..."
    echo 'export STELLAR_CORE_BINARY_PATH="/usr/bin/stellar-core"' >> "$HORIZON_ENV"
    ok "STELLAR_CORE_BINARY_PATH added"
else
    log "STELLAR_CORE_BINARY_PATH already exists (skipped)"
fi

if ! grep -q '^export CAPTIVE_CORE_STORAGE_PATH=' "$HORIZON_ENV"; then
    log "Adding CAPTIVE_CORE_STORAGE_PATH..."
    echo 'export CAPTIVE_CORE_STORAGE_PATH="/opt/stellar/horizon/captive-data"' >> "$HORIZON_ENV"
    ok "CAPTIVE_CORE_STORAGE_PATH added"
else
    log "CAPTIVE_CORE_STORAGE_PATH already exists (skipped)"
fi

if ! grep -q '^export CAPTIVE_CORE_CONFIG_PATH=' "$HORIZON_ENV"; then
    log "Adding CAPTIVE_CORE_CONFIG_PATH..."
    echo 'export CAPTIVE_CORE_CONFIG_PATH="/opt/stellar/horizon/etc/stellar-core-captive.yml"' >> "$HORIZON_ENV"
    ok "CAPTIVE_CORE_CONFIG_PATH added"
else
    log "CAPTIVE_CORE_CONFIG_PATH already exists (skipped)"
fi

if ! grep -q '^export CAPTIVE_CORE_HTTP_PORT=' "$HORIZON_ENV"; then
    log "Adding CAPTIVE_CORE_HTTP_PORT..."
    echo 'export CAPTIVE_CORE_HTTP_PORT=11726' >> "$HORIZON_ENV"
    ok "CAPTIVE_CORE_HTTP_PORT added"
else
    log "CAPTIVE_CORE_HTTP_PORT already exists (skipped)"
fi

# ------------------------------------------------------------------------------
# Step 6: Create captive core config file
# ------------------------------------------------------------------------------

if [[ ! -f "$CAPTIVE_CONFIG" ]]; then
    log "Creating captive core config: $CAPTIVE_CONFIG"
    cat > "$CAPTIVE_CONFIG" << 'EOF'
NETWORK_PASSPHRASE = "Pi Network"

[[VALIDATORS]]
NAME="validator1"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GDLA3KOMXKNHU5AGQB2R5VRBYCKM4X37NQVHTWRIQXNCOFOW4MZZSDTL"
ADDRESS="34.95.11.164:31402"
HISTORY="curl -sf https://history.mainnet.minepi.com/{0} -o {1}"

[[VALIDATORS]]
NAME="validator2"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GDGGD5XGBWLYS4XYJSUCX2CQ7ZS2JKIQTDOMPMPUU6LX74AINMRH2LMI"
ADDRESS="34.88.93.19:31402"
HISTORY="curl -sf https://history.mainnet.minepi.com/{0} -o {1}"

[[VALIDATORS]]
NAME="validator3"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GAXTE5AV5OCOEGJE4OPVMN5UJHAKDQCSVMXI4P7SZIGQXVO7LP4JKX4M"
ADDRESS="34.64.252.77:31502"
HISTORY="curl -sf https://history.mainnet.minepi.com/{0} -o {1}"
EOF
    ok "Captive core config created"
else
    log "Captive core config already exists (skipped)"
fi

# ------------------------------------------------------------------------------
# Step 7: Create captive data directory
# ------------------------------------------------------------------------------

if [[ ! -d "$CAPTIVE_DATA_DIR" ]]; then
    log "Creating captive data directory: $CAPTIVE_DATA_DIR"
    mkdir -p "$CAPTIVE_DATA_DIR"
    ok "Captive data directory created"
else
    log "Captive data directory already exists (skipped)"
fi
chown stellar:stellar "$CAPTIVE_DATA_DIR"

# ------------------------------------------------------------------------------
# Step 8: Restart services (only if supervisor is running)
# ------------------------------------------------------------------------------

if supervisorctl status &>/dev/null; then
    log "Supervisor is running, restarting horizon..."
    supervisorctl reread
    supervisorctl update
    supervisorctl restart horizon || die "Failed to restart horizon"
    ok "Horizon restarted"
else
    log "Supervisor not running, skipping restart"
fi

# ------------------------------------------------------------------------------
# Verification
# ------------------------------------------------------------------------------

log "Verifying migration..."

if grep -q '^export STELLAR_CORE_DATABASE_URL=' "$HORIZON_ENV"; then
    die "Verification failed: STELLAR_CORE_DATABASE_URL still present"
fi

if grep -q '^export STELLAR_CORE_URL=' "$HORIZON_ENV"; then
    die "Verification failed: STELLAR_CORE_URL still present"
fi

if ! grep -q 'ENABLE_CAPTIVE_CORE_INGESTION="true"' "$HORIZON_ENV"; then
    die "Verification failed: ENABLE_CAPTIVE_CORE_INGESTION not set to true"
fi

if ! grep -q '^export STELLAR_CORE_BINARY_PATH=' "$HORIZON_ENV"; then
    die "Verification failed: STELLAR_CORE_BINARY_PATH not found"
fi

if ! grep -q '^export CAPTIVE_CORE_CONFIG_PATH=' "$HORIZON_ENV"; then
    die "Verification failed: CAPTIVE_CORE_CONFIG_PATH not found"
fi

if [[ ! -f "$CAPTIVE_CONFIG" ]]; then
    die "Verification failed: Captive core config not found"
fi

if [[ ! -d "$CAPTIVE_DATA_DIR" ]]; then
    die "Verification failed: Captive data directory not found"
fi

ok "Verification passed"
ok "Migration completed successfully"

