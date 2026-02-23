#!/usr/bin/env bash
#
# Migration 001: Enable Captive Core for Horizon (unified multi-environment)
#
# Changes:
#   - Ensures APPLY_MIGRATIONS=true is present in horizon.env
#   - Removes STELLAR_CORE_DATABASE_URL and STELLAR_CORE_URL
#   - Sets ENABLE_CAPTIVE_CORE_INGESTION to true
#   - Updates HISTORY_ARCHIVE_URLS per environment
#   - Adds STELLAR_CORE_BINARY_PATH, CAPTIVE_CORE_STORAGE_PATH,
#     CAPTIVE_CORE_CONFIG_PATH, CAPTIVE_CORE_HTTP_PORT
#   - Creates stellar-core-captive.yml if not exists (env-specific)
#   - Creates captive-data directory
#
# Supported environments: mainnet, testnet, testnet2
# Idempotent: Safe to run multiple times
#

set -euo pipefail

HORIZON_ENV="/opt/stellar/horizon/etc/horizon.env"
CAPTIVE_CONFIG="/opt/stellar/horizon/etc/stellar-core-captive.yml"
CAPTIVE_DATA_DIR="/opt/stellar/horizon/captive-data"
CORE_CFG="/opt/stellar/core/etc/stellar-core.cfg"
BACKUP_DIR="${MIGRATION_BACKUP_DIR:-/opt/stellar/migration_backups}"

log()   { echo "$(date '+%Y-%m-%d %H:%M:%S') [001] [INFO]  $*"; }
ok()    { echo "$(date '+%Y-%m-%d %H:%M:%S') [001] [OK]    $*"; }
error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [001] [ERROR] $*" >&2; }
die()   { error "$*"; exit 1; }

log "Starting migration: Enable Captive Core (multi-environment)"

[[ -f "$HORIZON_ENV" ]] || die "Horizon env file not found: $HORIZON_ENV"
[[ -f "$CORE_CFG"    ]] || die "Core config file not found: $CORE_CFG"

# ==============================================================================
# Step 0: Detect environment from history URLs in stellar-core.cfg
# ==============================================================================
if grep -q "history.mainnet.minepi.com" "$CORE_CFG"; then
    ENV="mainnet"
elif grep -q "history.testnet2.minepi.com" "$CORE_CFG"; then
    ENV="testnet2"
elif grep -q "history.testnet.minepi.com" "$CORE_CFG"; then
    ENV="testnet"
else
    die "Cannot detect environment from $CORE_CFG"
fi
log "Detected environment: $ENV"

case "$ENV" in
    mainnet)  HISTORY_URLS="https://history.mainnet.minepi.com" ;;
    testnet)  HISTORY_URLS="https://history.testnet.minepi.com/" ;;
    testnet2) HISTORY_URLS="https://history.testnet2.minepi.com/" ;;
esac

# ==============================================================================
# Backup
# ==============================================================================
mkdir -p "$BACKUP_DIR"
BACKUP="$BACKUP_DIR/horizon.env.$(date +%Y%m%d_%H%M%S)"
cp "$HORIZON_ENV" "$BACKUP"
log "Backup created: $BACKUP"

# ==============================================================================
# Step 1: Ensure APPLY_MIGRATIONS=true
# ==============================================================================
if grep -q "^export APPLY_MIGRATIONS=true" "$HORIZON_ENV"; then
    log "APPLY_MIGRATIONS=true already present (skipped)"
else
    echo "export APPLY_MIGRATIONS=true" >> "$HORIZON_ENV"
    ok "APPLY_MIGRATIONS=true added"
fi

# ==============================================================================
# Step 2: Remove STELLAR_CORE_DATABASE_URL
# ==============================================================================
if grep -q "^export STELLAR_CORE_DATABASE_URL=" "$HORIZON_ENV"; then
    sed -i '/^export STELLAR_CORE_DATABASE_URL=/d' "$HORIZON_ENV"
    ok "STELLAR_CORE_DATABASE_URL removed"
else
    log "STELLAR_CORE_DATABASE_URL not present (skipped)"
fi

# ==============================================================================
# Step 3: Remove STELLAR_CORE_URL
# ==============================================================================
if grep -q "^export STELLAR_CORE_URL=" "$HORIZON_ENV"; then
    sed -i '/^export STELLAR_CORE_URL=/d' "$HORIZON_ENV"
    ok "STELLAR_CORE_URL removed"
else
    log "STELLAR_CORE_URL not present (skipped)"
fi

# ==============================================================================
# Step 4: Set ENABLE_CAPTIVE_CORE_INGESTION to true
# ==============================================================================
if grep -q 'ENABLE_CAPTIVE_CORE_INGESTION="true"' "$HORIZON_ENV"; then
    log "ENABLE_CAPTIVE_CORE_INGESTION already true (skipped)"
elif grep -q 'ENABLE_CAPTIVE_CORE_INGESTION="false"' "$HORIZON_ENV"; then
    sed -i 's/ENABLE_CAPTIVE_CORE_INGESTION="false"/ENABLE_CAPTIVE_CORE_INGESTION="true"/' "$HORIZON_ENV"
    ok "ENABLE_CAPTIVE_CORE_INGESTION set to true"
else
    echo 'export ENABLE_CAPTIVE_CORE_INGESTION="true"' >> "$HORIZON_ENV"
    ok "ENABLE_CAPTIVE_CORE_INGESTION added"
fi

# ==============================================================================
# Step 5: Update HISTORY_ARCHIVE_URLS
# ==============================================================================
if grep -qF "HISTORY_ARCHIVE_URLS=\"$HISTORY_URLS\"" "$HORIZON_ENV"; then
    log "HISTORY_ARCHIVE_URLS already correct (skipped)"
elif grep -q "^export HISTORY_ARCHIVE_URLS=" "$HORIZON_ENV"; then
    sed -i "s|^export HISTORY_ARCHIVE_URLS=.*|export HISTORY_ARCHIVE_URLS=\"$HISTORY_URLS\"|" "$HORIZON_ENV"
    ok "HISTORY_ARCHIVE_URLS updated"
else
    echo "export HISTORY_ARCHIVE_URLS=\"$HISTORY_URLS\"" >> "$HORIZON_ENV"
    ok "HISTORY_ARCHIVE_URLS added"
fi

# ==============================================================================
# Step 6: Add captive core environment variables
# ==============================================================================
if ! grep -q "^export STELLAR_CORE_BINARY_PATH=" "$HORIZON_ENV"; then
    echo 'export STELLAR_CORE_BINARY_PATH="/usr/bin/stellar-core"' >> "$HORIZON_ENV"
    ok "STELLAR_CORE_BINARY_PATH added"
else
    log "STELLAR_CORE_BINARY_PATH already exists (skipped)"
fi

if ! grep -q "^export CAPTIVE_CORE_STORAGE_PATH=" "$HORIZON_ENV"; then
    echo 'export CAPTIVE_CORE_STORAGE_PATH="/opt/stellar/horizon/captive-data"' >> "$HORIZON_ENV"
    ok "CAPTIVE_CORE_STORAGE_PATH added"
else
    log "CAPTIVE_CORE_STORAGE_PATH already exists (skipped)"
fi



if ! grep -q "^export CAPTIVE_CORE_CONFIG_PATH=" "$HORIZON_ENV"; then
    echo 'export CAPTIVE_CORE_CONFIG_PATH="/opt/stellar/horizon/etc/stellar-core-captive.yml"' >> "$HORIZON_ENV"
    ok "CAPTIVE_CORE_CONFIG_PATH added"
else
    log "CAPTIVE_CORE_CONFIG_PATH already exists (skipped)"
fi

if ! grep -q "^export CAPTIVE_CORE_HTTP_PORT=" "$HORIZON_ENV"; then
    echo 'export CAPTIVE_CORE_HTTP_PORT=11726' >> "$HORIZON_ENV"
    ok "CAPTIVE_CORE_HTTP_PORT added"
else
    log "CAPTIVE_CORE_HTTP_PORT already exists (skipped)"
fi

# ==============================================================================
# Step 7: Create captive core config if not exists (env-specific)
# ==============================================================================
if [[ ! -f "$CAPTIVE_CONFIG" ]]; then
    log "Creating captive core config for $ENV: $CAPTIVE_CONFIG"
    case "$ENV" in
        mainnet)
            cat > "$CAPTIVE_CONFIG" << 'TOML'
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
TOML
            ;;
        testnet)
            cat > "$CAPTIVE_CONFIG" << 'TOML'
NETWORK_PASSPHRASE = "Pi Testnet"

[[VALIDATORS]]
NAME="testnet1"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GC6R2IQ7LAEWFFNV2ZMXPMOLGGCFRFX6NQFCNT2PLB3KVJPHTIYV4ZPR"
ADDRESS="161.35.227.222:31402"
HISTORY="curl -sf https://history.testnet.minepi.com/{0} -o {1}"

[[VALIDATORS]]
NAME="testnet2"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GDRIZZC5PNZ6XBJTBZX52WX4NQ2K4Y5XBKVBRYNFDDS4VO6POQ3IGZCL"
ADDRESS="161.35.227.224:31402"
HISTORY="curl -sf https://history.testnet.minepi.com/{0} -o {1}"

[[VALIDATORS]]
NAME="testnet3"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GAKI7FNXWIJHKV4CKFSU6KDNFTPYAUOP2WIKL5IFSOPEUSYK4Y3LWMXX"
ADDRESS="161.35.238.87:31402"
HISTORY="curl -sf https://history.testnet.minepi.com/{0} -o {1}"
TOML
            ;;
        testnet2)
            cat > "$CAPTIVE_CONFIG" << 'TOML'
NETWORK_PASSPHRASE = "Pi Testnet"

[[VALIDATORS]]
NAME="validator1"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GDFDDPMCL4WPV27Z5Q7R6I2BX3UXOHJIU6AXXIFOCUEDEA4GWU2I4TJZ"
ADDRESS="34.152.3.42:31402"
HISTORY="curl -sf https://history.testnet2.minepi.com/{0} -o {1}"

[[VALIDATORS]]
NAME="validator2"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GDOJPADI56GTIP46K6YSRFOSEL2BW5WCYIKPFB5ZMY7YT3H2FRSAGI4J"
ADDRESS="35.228.163.61:31402"
HISTORY="curl -sf https://history.testnet2.minepi.com/{0} -o {1}"

[[VALIDATORS]]
NAME="validator3"
QUALITY="HIGH"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GAOBNDXTZSMJB5N3J5V5RZLYRN4EKQS5GIT25LCQS4AIBUJ3SMVMDR2Q"
ADDRESS="34.79.206.31:31402"
HISTORY="curl -sf https://history.testnet2.minepi.com/{0} -o {1}"
TOML
            ;;
    esac
    ok "Captive core config created for $ENV"
else
    log "Captive core config already exists (skipped)"
fi

# ==============================================================================
# Step 8: Create captive data directory
# ==============================================================================
if [[ ! -d "$CAPTIVE_DATA_DIR" ]]; then
    mkdir -p "$CAPTIVE_DATA_DIR"
    ok "Captive data directory created"
else
    log "Captive data directory already exists (skipped)"
fi
chown stellar:stellar "$CAPTIVE_DATA_DIR"

# ==============================================================================
# Verification
# ==============================================================================
log "Verifying migration..."
grep -q "^export APPLY_MIGRATIONS=true"            "$HORIZON_ENV" || die "APPLY_MIGRATIONS not set"
! grep -q "^export STELLAR_CORE_DATABASE_URL="     "$HORIZON_ENV" || die "STELLAR_CORE_DATABASE_URL still present"
! grep -q "^export STELLAR_CORE_URL="              "$HORIZON_ENV" || die "STELLAR_CORE_URL still present"
grep -q 'ENABLE_CAPTIVE_CORE_INGESTION="true"'     "$HORIZON_ENV" || die "ENABLE_CAPTIVE_CORE_INGESTION not true"
grep -q "^export STELLAR_CORE_BINARY_PATH="        "$HORIZON_ENV" || die "STELLAR_CORE_BINARY_PATH not found"
grep -q "^export CAPTIVE_CORE_CONFIG_PATH="        "$HORIZON_ENV" || die "CAPTIVE_CORE_CONFIG_PATH not found"
[[ -f "$CAPTIVE_CONFIG" ]]                                        || die "Captive core config not found"
[[ -d "$CAPTIVE_DATA_DIR" ]]                                      || die "Captive data directory not found"

ok "Verification passed"
ok "Migration completed successfully"
